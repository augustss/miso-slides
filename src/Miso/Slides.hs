{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
-- | Minimal definitions for writing presentation slides with miso.
--
-- A deck is a list of 'Slide's.  'runSlides' turns it into a miso
-- application that shows one slide at a time, scaled to fit the window
-- at a 16:9 aspect ratio.
--
-- Keys:
--
--   * next slide: Right, Down, Space, Enter, PageDown
--   * previous slide: Left, Up, Backspace, PageUp
--   * first / last slide: Home / End
--   * laser pointer on/off: P (see "Miso.Slides.Pointer")
--
-- On a touch screen, swipe left for the next slide, and right for the
-- previous one.
module Miso.Slides
  ( -- * Slides
    Slide (..)
  , Html
  , slide
  , titleSlide
  , titleSlideWith
  , author
    -- * Block content
  , para
  , bullets
  , numbered
  , codeBlock
  , codeLines
  , image
  , sizedImage
  , columns
  , table
    -- * Inline content
  , em
  , strong
  , tt
  , link
    -- * Running a deck
  , runSlides
  , slidesApp
  , Model
  , Action (..)
  ) where

import           Miso
import           Miso.CSS           (styleInline_)
import qualified Miso.Html          as H
import qualified Miso.Html.Property as P
import           Miso.JSON          (withArray, withObject, (.:))

import           Miso.Slides.Pointer (pointer, pointerCSS)

-----------------------------------------------------------------------------
-- Slides

-- | The state of a deck.
data Model = Model
  { slideIndex :: Int                     -- ^ the slide shown, from 0
  , swipeFrom  :: Maybe (Double, Double)  -- ^ where a one-finger touch started
  } deriving (Eq)

-- | Navigation actions.
data Action
  = Next
  | Prev
  | First
  | Last
  | GoTo Int
  | TouchStart [(Double, Double)]  -- ^ the fingers on the screen
  | TouchEnd [(Double, Double)]    -- ^ the fingers lifted
  | NoOp
  deriving (Show, Eq)

-- | Slide content.  'View' has an 'IsString' instance, so with
-- @OverloadedStrings@ a string literal can be used as 'Html'.
type Html = View () () Model Action

-- | A slide: a layout (a CSS class) and its content.
data Slide = Slide
  { slideLayout  :: MisoString
  , slideContent :: [Html]
  }

-- | An ordinary slide with a heading and a body.
slide :: MisoString -> [Html] -> Slide
slide title body = Slide "content" (H.h2_ [] [text title] : body)

-- | A slide with a large centered title and a subtitle.
titleSlide :: MisoString -> MisoString -> Slide
titleSlide title sub = titleSlideWith [] title sub []

-- | A title slide with more content above the title and below the subtitle.
titleSlideWith :: [Html] -> MisoString -> MisoString -> [Html] -> Slide
titleSlideWith above title sub below =
  Slide "title" (above ++ H.h1_ [] [text title] : H.p_ [P.class_ "subtitle"] [text sub] : below)

-- | The author's name, e.g., under the subtitle of a title slide.
author :: MisoString -> Html
author s = H.p_ [P.class_ "author"] [text s]

-----------------------------------------------------------------------------
-- Content

-- | A paragraph.
para :: [Html] -> Html
para = H.p_ []

-- | A bulleted list, one item per element.
bullets :: [Html] -> Html
bullets = H.ul_ [] . map (H.li_ [] . pure)

-- | A numbered list, one item per element.
numbered :: [Html] -> Html
numbered = H.ol_ [] . map (H.li_ [] . pure)

-- | A preformatted block of code.
codeBlock :: MisoString -> Html
codeBlock s = H.pre_ [] [H.code_ [] [text s]]

-- | A preformatted block of code, given as a list of lines.
codeLines :: [MisoString] -> Html
codeLines = codeBlock . mconcat . go
  where
    go []       = []
    go [l]      = [l]
    go (l : ls) = l : "\n" : go ls

-- | An image, given its URL.  It is as wide as the slide allows.
image :: MisoString -> Html
image url = H.img_ [P.src_ url]

-- | An image with a given height (a CSS length, e.g., @\"3em\"@), and its URL.
sizedImage :: MisoString -> MisoString -> Html
sizedImage h url = H.img_ [P.src_ url, P.class_ "sized", styleInline_ ("height: " <> h)]

-- | Side-by-side columns of equal width.
columns :: [[Html]] -> Html
columns = H.div_ [P.class_ "columns"] . map (H.div_ [P.class_ "column"])

-- | A table, given a header row (which may be empty) and the rows.
table :: [Html] -> [[Html]] -> Html
table hdr rows = H.table_ [] (thead ++ [H.tbody_ [] (map (row H.td_) rows)])
  where
    thead | null hdr  = []
          | otherwise = [H.thead_ [] [row H.th_ hdr]]
    row cell = H.tr_ [] . map (cell [] . pure)

-- | Emphasized text.
em :: MisoString -> Html
em s = H.em_ [] [text s]

-- | Strong text.
strong :: MisoString -> Html
strong s = H.strong_ [] [text s]

-- | Inline code.
tt :: MisoString -> Html
tt s = H.code_ [] [text s]

-- | A hyperlink: @link url label@.
link :: MisoString -> MisoString -> Html
link url s = H.a_ [P.href_ url] [text s]

-----------------------------------------------------------------------------
-- Running

-- | Run a deck as a miso application.
runSlides :: [Slide] -> IO ()
runSlides = startApp defaultEvents . slidesApp

-- | The miso application for a deck, in case you want to customize it
-- (e.g., add your own 'styles').
slidesApp :: [Slide] -> App Model Action
slidesApp slides =
  (component (Model 0 Nothing) (updateModel (length slides)) (viewModel slides))
    { subs   = [ windowSub "keydown" keycodeDecoder keyAction
               , windowSub "touchstart" (touchDecoder "touches") TouchStart
               , windowSub "touchend" (touchDecoder "changedTouches") TouchEnd
               ]
    , styles = [ Style slidesCSS, Style pointerCSS ]
    }

keyAction :: KeyCode -> Action
keyAction (KeyCode k)
  | k `elem` [39, 40, 32, 13, 34] = Next   -- right, down, space, enter, page down
  | k `elem` [37, 38, 8, 33]      = Prev   -- left, up, backspace, page up
  | k == 36                       = First  -- home
  | k == 35                       = Last   -- end
  | otherwise                     = NoOp

-- | The positions of the touches in a list of them, e.g., @touches@.
touchDecoder :: MisoString -> Decoder [(Double, Double)]
touchDecoder field = Decoder
  { decodeAt = DecodeTarget [field]
  , decoder  = withArray "touches" (mapM touch)
  }
  where
    touch = withObject "touch" $ \o -> (,) <$> o .: "clientX" <*> o .: "clientY"

-- | A swipe, from where a touch started to where it ended: mostly
-- horizontal, and at least 50 pixels long.
swipe :: (Double, Double) -> (Double, Double) -> Maybe Action
swipe (x0, y0) (x1, y1)
  | abs dx >= 50 && abs dx > 2 * abs dy = Just (if dx < 0 then Next else Prev)
  | otherwise                           = Nothing
  where
    dx = x1 - x0
    dy = y1 - y0

updateModel :: Int -> Action -> Effect () () Model Action
updateModel n = \case
  Next   -> move (+ 1)
  Prev   -> move (subtract 1)
  First  -> move (const 0)
  Last   -> move (const (n - 1))
  GoTo i -> move (const i)
  -- Only a one-finger touch can be a swipe; with two it is, e.g., a pinch.
  TouchStart [p] -> modify (\m -> m { swipeFrom = Just p })
  TouchStart _   -> modify (\m -> m { swipeFrom = Nothing })
  TouchEnd ps -> do
    m <- get
    put m { swipeFrom = Nothing }
    case (swipeFrom m, ps) of
      (Just p0, p1 : _) | Just a <- swipe p0 p1 -> updateModel n a
      _                                         -> pure ()
  NoOp   -> pure ()
  where
    move f = modify (\m -> m { slideIndex = max 0 (min (n - 1) (f (slideIndex m))) })

viewModel :: [Slide] -> Model -> Html
viewModel slides m =
  H.div_ [P.class_ "deck"]
    [ H.div_ [P.classes_ ["slide", slideLayout s]]
        (slideContent s ++ [H.div_ [P.class_ "slide-number"] [text slideNo]])
    , pointer i
    ]
  where
    s = case drop i slides of
          x : _ -> x
          []    -> Slide "title" ["(no slides)"]
    i = slideIndex m
    slideNo = ms (i + 1) <> " / " <> ms (length slides)

-----------------------------------------------------------------------------
-- Style

slidesCSS :: MisoString
slidesCSS = mconcat
  [ "html, body { margin: 0; height: 100%; overflow: hidden; background: #222; }"
  , ".deck { position: fixed; inset: 0; display: flex;"
  , "        align-items: center; justify-content: center; }"
    -- The slide is the largest 16:9 box that fits the window, and all
    -- sizes inside it are relative to its width, so it scales as a unit.
  , ".slide { --w: min(100vw, calc(100vh * 16 / 9));"
  , "         width: var(--w); height: calc(var(--w) * 9 / 16);"
  , "         font-size: calc(var(--w) / 36);"
  , "         box-sizing: border-box; padding: 5% 7%; position: relative;"
  , "         display: flex; flex-direction: column; overflow: hidden;"
  , "         background: #fdfdfb; color: #222;"
  , "         font-family: system-ui, -apple-system, 'Segoe UI', sans-serif; }"
  , ".slide > * { flex-shrink: 0; }"
  , ".slide.title { justify-content: center; align-items: center; text-align: center; }"
  , ".slide h1 { font-size: 2.6em; margin: 0 0 0.3em; }"
  , ".slide h2 { font-size: 1.6em; margin: 0 0 0.5em; padding-bottom: 0.2em;"
  , "            border-bottom: 0.06em solid #b33; }"
  , ".slide .subtitle { font-size: 1.2em; color: #666; margin: 0; }"
  , ".slide .author { font-size: 1.1em; margin: 0.8em 0 0; }"
  , ".slide p { margin: 0.4em 0; }"
  , ".slide ul, .slide ol { margin: 0.4em 0; }"
  , ".slide li { margin: 0.3em 0; }"
  , ".slide li > p { margin: 0; }"
  , ".slide code { font-family: ui-monospace, Menlo, Consolas, monospace; }"
  , ".slide :not(pre) > code { font-size: 0.85em; background: #f0f0eb;"
  , "                          padding: 0.05em 0.25em; border-radius: 0.2em; }"
  , ".slide pre { font-size: 0.75em; background: #f0f0eb; padding: 0.6em 0.9em; margin: 0.6em 0;"
  , "             border-radius: 0.3em; overflow: hidden; }"
  , ".slide img { width: 100%; max-height: 60%; object-fit: contain; }"
  , ".slide img.sized { width: auto; max-height: none; max-width: 100%; }"
  , ".slide.title img.sized { margin-bottom: 1.2em; }"
    -- Diagrams (Miso.Slides.Diagram)
  , ".row { display: flex; align-items: center; justify-content: center; gap: 1.2em;"
  , "       margin: 0.4em 0; }"
  , ".flow { display: flex; align-items: stretch; gap: 0.3em; margin: 0.6em 0; }"
  , ".flow .box { flex: 1 1 0; display: flex; flex-direction: column; justify-content: center;"
  , "             align-items: center; text-align: center; font-size: 0.8em; line-height: 1.2;"
  , "             padding: 0.4em 0.3em; border: 0.07em solid #b33; border-radius: 0.35em;"
  , "             background: #fbeeec; }"
  , ".flow .box small { font-size: 0.75em; color: #666; margin-top: 0.2em; }"
  , ".flow .arrow { align-self: center; color: #b33; }"
  , ".slide.title .flow { width: 80%; margin-top: 1.5em; }"
  , ".fields { display: flex; font-size: 0.7em; }"
  , ".field { box-sizing: border-box; flex: none; text-align: center; padding: 0.2em 0;"
  , "         border: 0.08em solid #555; border-left: none; background: #fff;"
  , "         font-family: ui-monospace, Menlo, Consolas, monospace; white-space: nowrap; }"
  , ".field:first-child { border-left: 0.08em solid #555; }"
  , ".graph { display: flex; justify-content: center; }"
  , ".graph svg { max-width: 100%; height: auto; }"
  , ".slide a { color: #b33; }"
  , ".slide table { border-collapse: collapse; margin: 0.4em 0; }"
  , ".slide th, .slide td { text-align: left; vertical-align: top;"
  , "                       padding: 0.2em 1.2em 0.2em 0; border-bottom: 0.04em solid #ddd; }"
  , ".slide th { color: #b33; font-weight: 600; }"
  , ".slide td:first-child { font-weight: 600; }"
  , ".columns { display: flex; gap: 2em; }"
  , ".column { flex: 1; min-width: 0; }"
  , ".slide-number { position: absolute; right: 1.5em; bottom: 1em;"
  , "                font-size: 0.6em; color: #999; }"
  ]
