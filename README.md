# miso-slides

Write presentation slides in Haskell, and show them in a browser with
[miso](https://haskell-miso.org).

**[See the demo](https://augustss.github.io/miso-slides/)**: a presentation
about [MicroHs](https://github.com/augustss/MicroHs), made with this
library (`app/Main.hs`).

```haskell
{-# LANGUAGE OverloadedStrings #-}
import Miso.Slides

main :: IO ()
main = runSlides
  [ titleSlide "My Talk" "A subtitle"
  , slide "First point"
      [ bullets ["one", "two", para ["three, with ", em "emphasis"]] ]
  , slide "Some code"
      [ codeBlock "main = putStrLn \"hello\"" ]
  ]
```

Navigate with the arrow keys, Space/Backspace, PageUp/PageDown, and Home/End.
On a phone or tablet, swipe left for the next slide and right for the
previous one.
P turns a laser pointer on and off: a red blob that follows the mouse and
leaves a fading trail (`Miso.Slides.Pointer`).  Hold the left button down
while moving it to draw; the drawing stays until the slide changes.

## The library (`Miso.Slides`)

| Definition | Meaning |
|---|---|
| `Slide` | A layout (a CSS class) and a list of `Html` content |
| `slide title body` | A slide with a heading |
| `titleSlide title subtitle` | A centered title slide |
| `titleSlideWith above title subtitle below` | A title slide with more content, e.g., a logo above |
| `author name` | The author's name, e.g., below the subtitle |
| `para`, `bullets`, `numbered` | Paragraph, bulleted list, numbered list (`[Html] -> Html`) |
| `codeBlock`, `codeLines` | Preformatted code, as one string or as a list of lines |
| `image`, `sizedImage height` | An image URL, full width or with a given CSS height |
| `columns`, `table` | Side-by-side columns, a table (header row may be empty) |
| `em`, `strong`, `tt`, `link` | Inline text |
| `runSlides` | Run a deck as a miso app |
| `slidesApp` | The underlying miso `App`, for customizing (e.g. extra `styles`) |

`Miso.Slides.Diagram` has simple diagrams:

| Definition | Meaning |
|---|---|
| `flow [[Html]]` | Boxes connected by arrows (each box's items are stacked) |
| `fields [(Int, Html)]` | Adjacent boxes with relative widths, e.g., the bits of a word |
| `graph g` | An application graph (`:@`, `Leaf`, `Mark`, `Share`/`Ref` for sharing), drawn as SVG |
| `row`, `small` | Items side by side; small caption text |

Images go in `static/`, which `miso build` copies to `public/`.

`Html` is miso's `View` type, so any element from `Miso.Html` can be used
as slide content, and string literals are `Html` with `OverloadedStrings`.

Slides are 16:9 and scale to fit the window; all sizes are relative to the
slide width.

## Building

The project is built with the `miso` command-line tool (miso-cli), which
compiles with MicroHs; the project is described by `miso.yml`.
`app/Main.hs` contains a presentation about MicroHs.

To install miso-cli:

```
curl -fsSL https://haskell-miso.org/download | sh
miso doctor     # check the installation and the tools it needs
```

The installer downloads the release for your OS and architecture and
unpacks it into `~/.miso`; it asks before changing your `PATH`.  miso
needs a C compiler (`cc`), and [emscripten](https://emscripten.org)
(`emcc`) for the browser target this project uses.  See the
[miso CLI docs](https://haskell-miso.org/docs/cli/) for more.

Then, in a clone of this repository:

```
miso dev        # build, serve, and reload the page when a source file changes
miso build      # just build: public/index.js, next to the files from static/
miso serve      # serve public/
miso watch      # type check on every change
```

`target` in `miso.yml` picks the output: `browser` (WebAssembly, needs
`emcc`), `browser_js` (JavaScript), or `native`.

Every push to `main` rebuilds the demo, and publishes it with GitHub Pages
(`.github/workflows/pages.yml`).

## License

Apache License 2.0; see `LICENSE`.
