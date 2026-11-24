{-# LANGUAGE OverloadedStrings #-}
-- | A presentation about MicroHs.
module Main (main) where

import Miso.String (MisoString)
import Miso.Slides
import Miso.Slides.Diagram

main :: IO ()
main = runSlides deck

deck :: [Slide]
deck =
  [ bookmark 0 $
    titleSlideWith
      [ sizedImage "2.6em" "haskell-symbol.svg" ]
      "MicroHs" "A small compiler for Haskell"
      [ author "Lennart Augustsson"
      , flow [["Haskell"], ["λ-calculus"], ["Combinators"], ["C runtime"]]
      ]

  , slide "What is MicroHs?"
      [ bullets
          [ "A compiler for Haskell 2010, plus many GHC extensions"
          , "It translates Haskell to combinators…"
          , "…which a small, portable runtime written in C executes"
          , "Written in MicroHs: it compiles itself"
          , para ["To build it you need ", strong "only a C compiler"]
          , "Small enough to run on micro-controllers"
          ]
      ]

  , slide "Hello, MicroHs"
      [ codeLines
          [ "fac :: Integer -> Integer"
          , "fac 0 = 1"
          , "fac n = n * fac (n - 1)"
          , ""
          , "main :: IO ()"
          , "main = print (map fac [1, 5, 20])"
          ]
      , codeLines
          [ "$ mhs Example -oEx      # compile to an executable"
          , "$ ./Ex"
          , "[1,120,2432902008176640000]"
          , "$ mhs -r Example        # or run it directly"
          , "[1,120,2432902008176640000]"
          ]
      ]

  , slide "By the numbers"
      [ table []
          [ ["Compiler",         "36 modules, 14,600 lines of Haskell"]
          , ["Runtime core",     "eval.c, 9,800 lines of C"]
          , ["Libraries",        "241 modules, 36,000 lines of Haskell"]
          , ["mhs binary",       "0.5 MB"]
          , ["Self-compilation", "6.9 s, 1.27 billion reductions"]
          , ["History",          "First commit May 2023; 4,600 commits"]
          ]
      , para ["MicroHs 0.17.3, Apple M6; base precompiled"]
      ]

  , slide "The language"
      [ bullets
          [ "Haskell 2010, with a few small differences"
          , para ["87 extensions, ", em "always on", "; LANGUAGE pragmas are ignored (except CPP)"]
          , "GADTs, RankNTypes, PolyKinds, TypeApplications, PatternSynonyms, DerivingVia, OverloadedRecordDot, …"
          , "Deriving for Eq, Ord, Show, Read, Enum, Bounded, Ix, Functor, Foldable, Traversable, Generic, Data, Lift"
          , para ["Records: ", tt "r.a", ", and nested updates ", tt "r{ a.b.c = e }"]
          ]
      ]

  , slide "Only in MicroHs: strings"
      [ para ["String interpolation"]
      , codeLines
          [ "greet :: String -> Int -> String"
          , "greet name n = s\"Hello ${name}, you are number ${n + 1}\""
          ]
      , codeLines
          [ "mhs> greet \"Lennart\" 41"
          , "\"Hello Lennart, you are number 42\""
          ]
      , para ["Qualified strings: ", tt "T.\"abc\"", " means ", tt "T.fromString \"abc\""]
      , para ["Extra commas: ", tt "[1, 2, 3,]", " (GHC is getting them too)"]
      ]

  , slide "Only in MicroHs: instances"
      [ para ["One instance declaration, several classes"]
      , codeLines
          [ "data Color = Red | Green"
          , "instance (Eq Color, Show Color) where"
          , "  Red   == Red   = True"
          , "  Green == Green = True"
          , "  _     == _     = False"
          , "  show Red   = \"Red\""
          , "  show Green = \"Green\""
          , ""
          , "type ES a = (Eq a, Show a)    -- a constraint synonym"
          , "instance ES Color where ...   -- the same instance"
          ]
      ]

  , slide "Error messages"
      [ image "nice-errors.svg"
      , para ["New in 0.17: the offending source line, in color (", tt "NO_COLOR", " turns it off)"]
      ]

  , slide "The compiler"
      [ flow
          [ ["Parse", small "with layout"]
          , ["Derive", small "instances"]
          , ["Type check", small "and fixities"]
          , ["Desugar", small "to λ-calculus"]
          , ["Abstract", small "to combinators"]
          , ["Serialize", small "as text or C"]
          ]
      , bullets
          [ "Type checking turns classes into dictionary passing"
          , "Desugaring leaves a simple λ-calculus"
          , "Bracket abstraction removes all the λs"
          , para ["36 modules in ", tt "src/MicroHs/"]
          ]
      ]

  , slide "Type checking"
      [ bullets
          [ "Follows “Practical type inference for arbitrary-rank types” (Peyton Jones et al.)"
          , "One checker for terms, types, and kinds: they share the syntax"
          , "Stratified: no type-in-type"
          , "Type equalities are solved by unification, as they appear"
          , "Class constraints are collected, solved later, and become dictionary arguments"
          ]
      ]

  , slide "Combinators"
      [ codeLines
          [ "S   x y z   = x z (y z)       A  x y       = y"
          , "K   x y     = x               U  x y       = y x"
          , "I   x       = x               Z  x y z     = x y"
          , "B   x y z   = x (y z)         P  x y z     = z x y"
          , "C   x y z   = x z y           R  x y z     = y z x"
          , "S'  x y z w = x (y w) (z w)   O  x y z w   = w x y"
          , "B'  x y z w = x y (z w)       K2 x y z     = x"
          , "C'  x y z w = x (y w) z       K3 x y z w   = x"
          , "C'B x y z w = x z (y w)       Y  x         = x (Y x)"
          ]
      , para ["Turner's S K I B C S' B' C' (1979), plus combinators that measurements showed pay off. (Adding K5 made it slower!)"]
      ]

  , slide "Bracket abstraction"
      [ para ["Remove the λs with S, K, and I, then simplify"]
      , codeLines
          [ "S (K x) y        ⇒  B x y"
          , "S x (K y)        ⇒  C x y"
          , "S (B x y) z      ⇒  S' x y z"
          , "S K x            ⇒  I"
          , "S (K x) (K y)    ⇒  K (x y)"
          , "K I              ⇒  A"
          , "C I              ⇒  U"
          ]
      , para ["Local recursion uses ", tt "Y", "; top-level definitions refer to each other by name"]
      ]

  , slide "What comes out"
      [ codeLines
          [ "twice f x = f (f x)"
          , "flip f x y = f y x"
          , "swap (x, y) = (y, x)"
          , "map f Nil         = Nil"
          , "map f (Cons x xs) = Cons (f x) (map f xs)"
          ]
      , codeLines
          [ "twice = S B I"
          , "flip  = C"
          , "swap  = D_2 (C C_0_2)"
          , "map   = B Y (B (B (D_0_2 Nil)) (B C'B (B Cons)))"
          ]
      , para ["Output of ", tt "mhs -ddump-combinator"]
      ]

  , slide "A combinator graph"
      [ graph mapGraph
      , para [tt "map", " from the previous slide, as the runtime sees it"]
      ]

  , slide "Data types"
      [ codeLines
          [ "Nothing = C_0_0          Just 42 = C_1_1 42"
          , "x : xs  = C_1_2 x xs     (a, b)  = C_0_2 a b"
          , ""
          , "case xs of { [] -> a; y:ys -> b }  ⇒  D_0_2 a (\\ y ys -> b) xs"
          , "if c then t else e                 ⇒  D_0_0 e t c"
          ]
      , bullets
          [ "Constructors and case are built into the runtime (new in 0.17)"
          , "They are stored in the pointer itself, and take no heap space"
          ]
      ]

  , slide "How case works"
      [ row [graph caseBefore, "⇒", graph caseAfter]
      , bullets
          [ para [tt "D_0_2", " pushes a marker, and evaluates the scrutinee"]
          , para [tt "C_1_2", " finds the marker, and overwrites the case with ", tt "f y ys"]
          , para ["A sparse case, ", tt "E_…", ", has a default, and a few arms"]
          ]
      ]

  , slide "Type classes"
      [ para ["A dictionary is a function"]
      , codeLines
          [ "-- the dictionary of a class with n components"
          , "C$C = \\ x1 ... xn f -> f x1 ... xn"
          , ""
          , "-- select component i"
          , "\\ d -> d (\\ x1 ... xn -> xi)"
          , ""
          , "-- pure is component 2 of the 6 in Applicative"
          , "pure = U (K K4)"
          ]
      ]

  , slide "The runtime"
      [ bullets
          [ "A graph reduction machine, written in C"
          , "Preemptive lightweight threads, MVars, STM, weak pointers"
          , "FFI to C, and to JavaScript with emscripten"
          , "Integer: imath (the default), GMP, or pure Haskell"
          , "Serialization, LZMA decompression, UTF-8 I/O"
          ]
      ]

  , slide "Memory"
      [ table []
          [ ["Pointer",     fields [(29, "address"), (3, "00")]]
          , ["Tag",         fields [(8, "n:8"), (10, "k:11"), (11, "tag:11"), (3, "10")]]
          , ["Application", fields [(32, "function"), (32, "argument")]]
          , ["Value",       fields [(29, "tag"), (3, "11"), (32, "payload")]]
          ]
      , bullets
          [ "A cell is two words: an application, or a tag with a value"
          , para ["A tag needs no heap: combinators, and constructors ", tt "C_k_n"]
          , "A bitmap marks the cells; allocation takes runs of free cells"
          ]
      ]

  , slide "Graph reduction"
      [ row [graph sBefore, "⇒", graph sAfter]
      , bullets
          [ "Walk down the left spine, pushing the @ nodes on the stack"
          , "With enough arguments, overwrite the top @ (red) with the result"
          , para ["Everyone who points to it sees the result, and ", tt "x", " is shared, not copied"]
          ]
      ]

  , slide "The evaluator"
      [ codeLines
          [ "switch (tag) {"
          , "case X_AP:  PUSH(n); n = FUN(n); goto top;"
          , "case D_INT: RET;"
          , "/* S x y z = x z (y z) */"
          , "case T_S: GCCHECK(2); CHKARG3; GOAP2(x, z, new_ap(y, z));"
          , "/* K x y = *x */"
          , "case T_K: CHKARG2; GOIND(x);"
          , "/* B x y z = x (y z) */"
          , "case T_B: GCCHECK(1); CHKARG3; GOAP(x, new_ap(y, z));"
          , "/* n@(Y x) = x n */"
          , "case T_Y: CHKARG1; GOAP(x, n);"
          ]
      , para ["From ", tt "src/runtime/eval.c", " (reformatted)"]
      ]

  , slide "Code that specializes itself"
      [ codeLines
          [ "inc x = x + 1     -- inc  = S' C (+) (C fromInteger 1)"
          , "iinc = inc        -- iinc = inc d,  d = the Num Int dictionary"
          ]
      , row [graph specBefore, "⇒", graph specAfter]
      , para ["After the first call, ", tt "iinc", " is just ", tt "C + 1", ": the dictionary is gone"]
      ]

  , slide "IO, threads, and exceptions"
      [ bullets
          [ "An IO action takes a world token and returns a pair"
          , para ["The pair is built with ", tt "P", ", so ", tt "return", " is ", tt "P", " and ", tt ">>=", " is ", tt "C"]
          , "A thread is a root node; when its time slice ends, its stack is thrown away"
          , "All reductions were made in place, so evaluating the root again resumes it"
          , para [tt "catch", " uses ", tt "setjmp", ", ", tt "throw", " uses ", tt "longjmp"]
          ]
      ]

  , slide "Serialization"
      [ para ["Any value can be saved: even functions, sharing, and cycles"]
      , codeLines
          [ "data Shape = Circle Double | Rect Double Double"
          , "  deriving (Show, Data)"
          , ""
          , "main = do"
          , "  withBinaryFile \"s.ser\" WriteMode $ \\ h ->"
          , "    hSerializeDescr h [Circle 1, Rect 2 3]"
          , "  r <- withBinaryFile \"s.ser\" ReadMode hDeserializeDescr"
          , "  print (r :: Maybe [Shape])"
          ]
      , para ["Packages and the compilation cache are serialized compiler state"]
      ]

  , slide "The REPL"
      [ para ["To run code, the compiler serializes it, and the runtime reads it back as a value"]
      , codeLines
          [ "translateWithMap (TM mp) (ds, e) ="
          , "  let dm = foldr (uncurry M.insert) mp ds"
          , "      outCMdl = snd $ renumberCMdlM [] dm e"
          , "      str = toStringCMdl outCMdl    -- serialized value"
          , "      val = unsafePerformIO (readSerializedBS (pack str))"
          , "  in  val"
          ]
      , para ["From ", tt "src/MicroHs/Translate.hs"]
      ]

  , slide "Bootstrapping"
      [ flow
          [ [tt "generated/mhs.c", small "combinators"]
          , [strong "cc", small "+ runtime"]
          , [tt "bin/mhs"]
          , ["compiles", tt "src/MicroHs/"]
          , [tt "generated/mhs.c"]
          ]
      , bullets
          [ para [tt "make", ": a C compiler is all you need"]
          , para [tt "make bootstrap", ": compile the compiler twice, and compare"]
          , "From scratch (bootstrappable.org): with a patched Hugs"
          , "It also compiles with GHC, which is handy for development"
          ]
      ]

  , slide "Packages"
      [ bullets
          [ "A package is serialized compiler state, loaded when it is needed"
          , para [tt "mcabal", ": a subset of Cabal, written in Haskell 98; versions come from Stackage"]
          , "Known to work: containers, mtl, parsec, text, QuickCheck, hspec, optparse-applicative, async, …"
          , para ["Porting: ", tt "#ifdef __MHS__", ", ", tt "if impl(mhs)", ", and the ghc-compat package"]
          ]
      ]

  , slide "Platforms"
      [ columns
          [ [ strong "Big"
            , bullets
                [ "Linux, macOS, BSD"
                , "Windows (MSVC, MinGW)"
                , "JavaScript and WebAssembly (emscripten)"
                ]
            ]
          , [ strong "Small"
            , bullets
                [ "STM32F4 and ESP32"
                , "Bare metal: no file system needed"
                , "32 and 64 bit, little and big endian"
                ]
            ]
          ]
      , flow
          [ [tt "Blinky.hs"]
          , [strong "mhs", small "on the host"]
          , [tt "Blinky.c", small "combinators"]
          , [strong "C compiler", small "+ runtime"]
          , ["the board"]
          ]
      ]

  , slide "These slides"
      [ bullets
          [ para ["Written in Haskell, with ", link "https://haskell-miso.org" "miso"]
          , "Compiled by MicroHs, and by emscripten to WebAssembly"
          , para ["Built with miso-cli: ", tt "miso build"]
          ]
      , codeLines
          [ "deck :: [Slide]"
          , "deck ="
          , "  [ bookmark 0 $"
          , "    titleSlideWith [sizedImage \"2.6em\" \"haskell-symbol.svg\"]"
          , "      \"MicroHs\" \"A small compiler for Haskell\""
          , "      [author \"Lennart Augustsson\", flow ...]"
          , "  , slide \"What is MicroHs?\" [ ... ]"
          ]
      ]

  , slide "Try it"
      [ bullets
          [ link "https://github.com/augustss/MicroHs" "github.com/augustss/MicroHs"
          , link "https://augustss.github.io/MicroHs/web-mhs/" "MicroHs in your browser"
          , para ["The manual: ", tt "doc/MicroHs.md"]
          , para [em "MicroHs: A Small Compiler for Haskell", ", Haskell Symposium 2024"]
          ]
      ]

  , bookmark 9 $
    titleSlide "Thank you" "Questions?"
  ]

-----------------------------------------------------------------------------
-- Graphs

l :: MisoString -> Graph
l = Leaf

-- | map = B Y (B (B (D_0_2 Nil)) (B C'B (B Cons)))
mapGraph :: Graph
mapGraph =
  l "B" :@ l "Y" :@
    (l "B" :@ (l "B" :@ (l "D_0_2" :@ l "Nil")) :@ (l "B" :@ l "C'B" :@ (l "B" :@ l "Cons")))

-- | S f g x  ⇒  f x (g x), where the top node is overwritten
sBefore, sAfter :: Graph
sBefore = Mark (l "S" :@ l "f" :@ l "g" :@ l "x")
sAfter  = Mark (l "f" :@ Share "x" (l "x") :@ (l "g" :@ Ref "x"))

-- | case xs of { [] -> a; y:ys -> f y ys }, when xs is y:ys
caseBefore, caseAfter :: Graph
caseBefore = Mark (l "D_0_2" :@ l "a" :@ l "f" :@ (l "C_1_2" :@ l "y" :@ l "ys"))
caseAfter  = Mark (l "f" :@ l "y" :@ l "ys")

-- | iinc = inc d, after the S' reduction, and after evaluating its parts
specBefore, specAfter :: Graph
specBefore = Mark (l "C" :@ (l "(+)" :@ Share "d" (l "d")) :@ (l "C" :@ l "fromInteger" :@ l "1" :@ Ref "d"))
specAfter  = Mark (l "C" :@ l "+" :@ l "1")
