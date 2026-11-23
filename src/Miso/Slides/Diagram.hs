{-# LANGUAGE OverloadedStrings #-}
-- | Simple diagrams for slides: flow charts, rows of fields (e.g., the
-- bits of a machine word), and application graphs drawn as SVG.
--
-- All sizes are in @em@, so diagrams scale with the slide.
module Miso.Slides.Diagram
  ( -- * Layout
    row
  , small
    -- * Flow charts
  , flow
    -- * Fields
  , fields
    -- * Application graphs
  , Graph (..)
  , graph
  ) where

import           Data.Maybe         (fromMaybe)
import           Miso               (MisoString, fromMisoString, ms, text)
import           Miso.CSS           (styleInline_)
import qualified Miso.Html          as H
import qualified Miso.Html.Property as P
import qualified Miso.Svg           as S
import qualified Miso.Svg.Property  as SP

import           Miso.Slides        (Html)

-----------------------------------------------------------------------------
-- Layout

-- | Items side by side, centered, e.g., @row [before, \"⇒\", after]@.
row :: [Html] -> Html
row = H.div_ [P.class_ "row"]

-- | Small text, e.g., a caption in a 'flow' box.
small :: MisoString -> Html
small s = H.small_ [] [text s]

-----------------------------------------------------------------------------
-- Flow charts

-- | Boxes connected by arrows, left to right.  The items of each box are
-- stacked vertically.
flow :: [[Html]] -> Html
flow = H.div_ [P.class_ "flow"] . arrows . map (H.div_ [P.class_ "box"])
  where
    arrows (a : b : xs) = a : H.div_ [P.class_ "arrow"] ["→"] : arrows (b : xs)
    arrows xs           = xs

-----------------------------------------------------------------------------
-- Fields

-- | A row of adjacent boxes, given their widths (one unit is 0.5em of the
-- boxes' text) and contents, e.g., the fields of a machine word.
fields :: [(Int, Html)] -> Html
fields = H.div_ [P.class_ "fields"] . map field
  where
    field (w, x) =
      H.div_ [P.class_ "field", styleInline_ ("width: calc(" <> ms w <> " * 0.5em)")] [x]

-----------------------------------------------------------------------------
-- Application graphs

-- | An application graph, as the runtime sees it.
data Graph
  = Graph :@ Graph          -- ^ an application of a function to an argument
  | Leaf MisoString         -- ^ a combinator, constant, or variable
  | Mark Graph              -- ^ highlight the top node
  | Share MisoString Graph  -- ^ name a node, so that 'Ref' can point to it
  | Ref MisoString          -- ^ another edge to the node with this name
infixl 9 :@

data Node = Node
  { nodeX     :: Double
  , nodeY     :: Double
  , nodeLabel :: Maybe MisoString   -- Nothing for an application
  , nodeMark  :: Bool
  }

type Point = (Double, Double)

-- Layout, in em.  Leaves get consecutive horizontal slots (wide enough for
-- their labels); an application is centered above its two children.
leafWidth :: MisoString -> Double
leafWidth l = max 1.8 (0.54 * fromIntegral (length (fromMisoString l :: String)) + 0.9)

levelHeight :: Double
levelHeight = 1.45

layout :: Graph -> ([Node], [(Point, Point)], Double)
layout g = (nodes, edges, width)
  where
    (_, width, nodes, edges, names) = go 0 False 0 g
    find n = fromMaybe (error ("Miso.Slides.Diagram: no node " ++ show n)) (lookup n names)
    go :: Int -> Bool -> Double -> Graph
       -> (Point, Double, [Node], [(Point, Point)], [(MisoString, Point)])
    go d m s gr = case gr of
      Leaf l ->
        let w = leafWidth l
            p = (s + w / 2, y d)
        in  (p, s + w, [Node (fst p) (snd p) (Just l) m], [], [])
      Mark h -> go d True s h
      Share n h ->
        let (p, s', ns, es, env) = go d m s h
        in  (p, s', ns, es, (n, p) : env)
      Ref n -> (find n, s, [], [], [])
      f :@ a ->
        let (pf, s1, n1, e1, v1) = go (d + 1) False s f
            (pa, s2, n2, e2, v2) = go (d + 1) False s1 a
            p = ((fst pf + fst pa) / 2, y d)
        in  (p, s2, Node (fst p) (snd p) Nothing m : n1 ++ n2, (p, pf) : (p, pa) : e1 ++ e2, v1 ++ v2)
    y d = (fromIntegral d + 0.5) * levelHeight

-- | Draw an application graph.  Applications are drawn as @\@@ nodes,
-- with the function to the left and the argument to the right.
graph :: Graph -> Html
graph g =
  H.div_ [P.class_ "graph"]
    [ S.svg_ [ SP.viewBox_ ("0 0 " <> u width <> " " <> u height)
             , styleInline_ ("width: calc(" <> ms (round (width * 10) :: Int) <> " * 0.1em)")
             ]
        (map edge edges ++ map node nodes)
    ]
  where
    (nodes, edges, width) = layout g
    height = maximum (0 : map nodeY nodes) + levelHeight / 2
    -- SVG user units: 100 per em.
    u :: Double -> MisoString
    u x = ms (round (x * 100) :: Int)
    -- An edge stops short of the nodes at its ends, so it does not touch
    -- a label.
    edge ((x1, y1), (x2, y2)) =
      let dx = x2 - x1
          dy = y2 - y1
          k  = 0.45 / sqrt (dx * dx + dy * dy)
      in  S.line_ [ SP.x1_ (u (x1 + k * dx)), SP.y1_ (u (y1 + k * dy))
                  , SP.x2_ (u (x2 - k * dx)), SP.y2_ (u (y2 - k * dy))
                  , SP.stroke_ "#999", SP.strokeWidth_ "7" ]
    node n = case nodeLabel n of
      Nothing ->
        S.g_ []
          [ S.circle_ [ SP.cx_ (u (nodeX n)), SP.cy_ (u (nodeY n)), SP.r_ "42"
                      , SP.fill_ (if nodeMark n then "#f3d3cf" else "#fdfdfb")
                      , SP.stroke_ (if nodeMark n then "#b33" else "#999")
                      , SP.strokeWidth_ "7" ]
          , label "#666" "60" "@"
          ]
      Just l -> label (if nodeMark n then "#b33" else "#222") "90" l
      where
        label colour size s =
          S.text_ [ SP.x_ (u (nodeX n)), SP.y_ (u (nodeY n))
                  , SP.textAnchor_ "middle", SP.dominantBaseline_ "central"
                  , SP.fill_ colour, SP.fontSize_ size
                  , SP.fontWeight_ (if nodeMark n then "bold" else "normal")
                  , SP.fontFamily_ "ui-monospace, Menlo, Consolas, monospace"
                    -- a halo in the background colour hides the edges below
                  , styleInline_ "paint-order: stroke; stroke: #fdfdfb; stroke-width: 24px"
                  ]
            [text s]
