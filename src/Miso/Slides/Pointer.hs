{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
-- | A laser pointer: a red blob that follows the mouse and leaves a
-- fading trail.  The @P@ key turns it on and off; while it is on, the
-- ordinary mouse cursor is hidden, and the slide does not react to the
-- mouse.
--
-- Moving the pointer with the left button held down draws: the trail
-- stays, until the slide changes.
--
-- The pointer is a child component of its own, so moving the mouse
-- redraws only the pointer, not the slide.
module Miso.Slides.Pointer
  ( pointer
  , pointerCSS
  ) where

import           Miso                (Component (..), DecodeTarget (..), Decoder (..),
                                      Effect, KeyCode (..), MisoString, View, component,
                                      key_, keycodeDecoder, modify, mountWithProps_, ms,
                                      windowSub)
import           Miso.CSS            (styleInline_)
import qualified Miso.Html           as H
import qualified Miso.Html.Property  as P
import           Miso.JSON           (withObject, (.:))
import qualified Miso.Svg            as S
import qualified Miso.Svg.Property   as SP

-- | The pointer, to be put anywhere in a view, given the current slide
-- number.  When the number changes, what has been drawn is erased.
pointer :: Int -> View () props model action
pointer slideNo = mountWithProps_ "pointer" slideNo pointerComponent

-----------------------------------------------------------------------------
-- Model

type Point = (Int, Int)

-- | A piece of the trail, from one mouse position to the next.  The
-- number is its key: each segment gets its own DOM node, whose CSS
-- animation starts when it is created.
data Segment = Segment Int Point Point
  deriving (Eq)

data Model = Model
  { mouse   :: Maybe Point         -- ^ Nothing until the mouse has moved
  , visible :: Bool
  , nextKey :: Int
  , trail   :: [Segment]           -- ^ newest first
  , drawing :: Maybe MisoString    -- ^ the line being drawn, as SVG points
  , drawn   :: [MisoString]        -- ^ the lines drawn on this slide, newest first
  } deriving (Eq)

data Action
  = Toggle
  | Move Point Bool   -- ^ the mouse position, and if the left button is down
  | Erase
  | Ignore

-- | The longest trail, in segments.  It only needs to be long enough
-- for the segments to fade before they are dropped.
maxTrail :: Int
maxTrail = 80

pointerComponent :: Component () Int Model Action
pointerComponent =
  (component (Model Nothing False 0 [] Nothing []) update view)
    { subs = [ windowSub "keydown" keycodeDecoder key
             , windowSub "pointermove" moveDecoder (uncurry Move)
             ]
    , onPropsChanged = Just (\_ _ -> Erase)
    }
  where
    key (KeyCode 80) = Toggle   -- P
    key _            = Ignore

-- | The position of a @pointermove@ event, and whether the left button is
-- down.  (Looking at the buttons in every move, rather than waiting for a
-- button to be released, means that a release outside the window is not
-- missed.)
moveDecoder :: Decoder (Point, Bool)
moveDecoder = Decoder
  { decodeAt = DecodeTarget []
  , decoder  = withObject "pointermove" $ \o -> do
      x <- o .: "clientX"
      y <- o .: "clientY"
      b <- o .: "buttons"
      pure ((round (x :: Double), round (y :: Double)), odd (b :: Int))
  }

update :: Action -> Effect () Int Model Action
update = \case
  Toggle   -> modify (\m -> stopDrawing m { visible = not (visible m), trail = [] })
  Move p b -> modify (move p b)
  Erase    -> modify (\m -> m { drawing = Nothing, drawn = [] })
  Ignore   -> pure ()

-- The mouse position is tracked even when the pointer is off, so that
-- it shows up in the right place when it is turned on.
move :: Point -> Bool -> Model -> Model
move p down m = case mouse m of
  Just q | visible m && q /= p ->
    if down
      then m' { drawing = Just (maybe (point q) id (drawing m) <> " " <> point p) }
      else (stopDrawing m')
             { nextKey = nextKey m + 1
             , trail = take maxTrail (Segment (nextKey m) q p : trail m)
             }
  _ -> m'
  where
    m' = m { mouse = Just p }
    point (x, y) = ms x <> "," <> ms y

stopDrawing :: Model -> Model
stopDrawing m = case drawing m of
  Just l  -> m { drawing = Nothing, drawn = l : drawn m }
  Nothing -> m

-----------------------------------------------------------------------------
-- View

view :: Model -> View () Int Model Action
view m =
  H.div_ [P.class_ "pointer"] $
    S.svg_ []
      -- Oldest first, so a new line is added at the end.
      [ S.g_ [] (map line (reverse (drawn m) ++ maybe [] pure (drawing m)))
        -- Newest first: miso's keyed diff then adds a node at the front
        -- and removes one at the end.  (Removing from the front would move
        -- every other node, and restart its animation.)
      , S.g_ [] (map segment (trail m))
      ]
    : case mouse m of
        Just (x, y) | visible m ->
          [ H.div_ [ P.class_ "pointer-blob"
                   , styleInline_ ("transform: translate(" <> px x <> ", " <> px y <> ")")
                   ] []
          , H.style_ [] pointerOnCSS
          ]
        _ -> []
  where
    px :: Int -> MisoString
    px n = ms n <> "px"
    line ps = S.polyline_ [SP.points_ ps]
    segment (Segment k (x1, y1) (x2, y2)) =
      S.line_ [ key_ k
              , SP.x1_ (ms x1), SP.y1_ (ms y1), SP.x2_ (ms x2), SP.y2_ (ms y2) ]

-- | While the pointer is on, there is no mouse cursor, and the page does
-- not react to the mouse (so dragging does not select text, and a click
-- does not follow a link).
pointerOnCSS :: MisoString
pointerOnCSS = mconcat
  [ "html, body { cursor: none; user-select: none; -webkit-user-select: none; }"
  , "body > * { pointer-events: none; }"
  ]

-- | The pointer's style sheet.  The blob's size is relative to the size of
-- a slide.  Each trail segment narrows and fades as it gets older.
pointerCSS :: MisoString
pointerCSS = mconcat
  [ ".pointer { --pw: calc(min(100vw, 100vh * 16 / 9) / 60);"
  , "           position: fixed; inset: 0; pointer-events: none; z-index: 10; }"
    -- Where lines overlap, the darker (newer) one wins, whatever the
    -- order they are drawn in.
  , ".pointer svg { position: absolute; inset: 0; width: 100%; height: 100%;"
  , "               isolation: isolate; opacity: 0.85; }"
  , ".pointer line, .pointer polyline { stroke-linecap: round; mix-blend-mode: darken; }"
  , ".pointer line { stroke-width: 0; animation: pointer-trail 0.5s linear forwards; }"
  , "@keyframes pointer-trail {"
  , "  from { stroke-width: calc(var(--pw) * 0.7); stroke: #f01a1a; }"
  , "  to   { stroke-width: 0; stroke: #ffb3b3; } }"
  , ".pointer polyline { fill: none; stroke: #f01a1a; stroke-linejoin: round;"
  , "                    stroke-width: calc(var(--pw) * 0.5); }"
  , ".pointer-blob { position: absolute; left: 0; top: 0;"
  , "                width: var(--pw); height: var(--pw);"
  , "                margin: calc(var(--pw) / -2) 0 0 calc(var(--pw) / -2);"
  , "                border-radius: 50%;"
  , "                background: radial-gradient(circle at 40% 40%, #fff 0, #ff6b6b 25%, #e00 60%, #b00 100%);"
  , "                box-shadow: 0 0 calc(var(--pw) * 0.6) calc(var(--pw) * 0.15) rgba(255, 0, 0, 0.55); }"
  ]
