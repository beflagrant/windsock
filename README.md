# Windsock

Read your Tailwind v4 theme from Ruby.

Tailwind v4 keeps your design tokens in CSS: `@theme { --color-brand-500: oklch(...) }`. That's the right place for them, but sometimes Ruby needs the same values. Windsock parses the stylesheet so you don't keep a second copy.

```ruby
Windsock.color(:brand, 500).to_hex   # => "#2b7fff"
Windsock.scale(:brand)               # => every brand-* step, with WCAG contrast
Windsock.scale_names                 # => ["red", "orange", ..., "brand"]
Windsock.theme.breakpoints["md"]     # => "48rem"
Windsock.theme.fonts["sans"]         # => "ui-sans-serif, system-ui, ..."
```

Where it helps:

- **Mailers.** Email clients ignore CSS variables and don't understand `oklch()`. `tailwind_color(:brand, 500)` gives you a hex value to inline.
- **PDFs, OG images, charts.** Prawn, Grover, Chartkick and friends want plain colors.
- **Meta tags and manifests.** `theme-color`, PWA `manifest.json`.
- **Tests.** Assert your brand palette is what you think it is.

No Node, no Tailwind binary. It reads the CSS, resolves `@import` and `var()`, and converts colors.

## Install

```ruby
gem "windsock"
```

## Rails

Windsock reads `app/assets/tailwind/application.css` (the tailwindcss-rails default) and reloads when any `.css` in that directory changes in development.

```ruby
# config/application.rb (only if your stylesheet lives elsewhere)
config.windsock.path = Rails.root.join("app/assets/stylesheets/main.css")
```

Views and mailers get helpers:

```erb
<a style="background: <%= tailwind_color(:brand, 500) %>; color: <%= tailwind_color(:white) %>">
<meta name="theme-color" content="<%= tailwind_color(:brand, 900) %>">
<%= tailwind_color(:brand, 500, format: :rgb) %>   <%# rgb(43 127 255) %>
<%= tailwind_color(:brand, 500, format: :rgba) %>  <%# rgba(43, 127, 255, 1) — safest for email %>
<%= tailwind_color(:brand, 500, format: :css) %>   <%# the value as written %>
<%= tailwind_text_color(:brand, 500) %>            <%# the theme's black or white, whichever reads better on brand-500 %>
<%= tailwind_value(:breakpoint, :md) %>            <%# 48rem %>
```

## Without Rails

```ruby
Windsock.path = "path/to/application.css"
Windsock.theme

# or
theme = Windsock.load("path/to/application.css")
theme = Windsock.parse(css_string, base_dir: "dir/for/relative/imports")
```

## Theme API

```ruby
theme = Windsock.theme

theme[:color, :brand, 500]      # "oklch(62.3% 0.214 259.815)" — var() references resolved
theme["color-brand-500"]        # same thing
theme.raw(:color, :primary)     # "var(--color-brand-500)" — as written
theme.fetch(:nope)              # raises Windsock::NotFound
theme.key?(:color, :blue, 500)

theme.color(:brand, 500)        # => Windsock::Color (or nil)
theme.color!(:brand, 500)       # raises if missing
theme.color(:brand)             # => the brand Scale when there is no --color-brand but there are brand-* steps
theme.white, theme.black        # --color-white / --color-black, else pure #fff / #000
theme.text_color(:brand, 500)   # theme.white or theme.black, whichever reads better on brand-500
theme.colors                    # { "brand-500" => Color, "red-50" => Color, ... }
theme.scale(:brand)             # Windsock::Scale: 50 => Color, ..., 950 => Color
theme.scale_names               # ["red", "orange", ..., "brand"] — what #scale accepts
theme.scales                    # { "brand" => Scale, "red" => Scale, ... }

theme.breakpoints               # { "sm" => "40rem", "md" => "48rem", ... }
theme.fonts, theme.radii, theme.shadows, theme.text_sizes, theme.containers,
theme.tracking, theme.leading, theme.easings, theme.animations, theme.blurs
theme.namespace(:anything)      # any --anything-* prefix

theme.spacing                   # "0.25rem"
theme.spacing(4)                # "1rem"
theme.spacing(:gutter)          # a named --spacing-gutter

theme.to_h                      # every variable, resolved
Windsock.default_theme          # Tailwind's stock palette, untouched

# Shortcuts on the module go to Windsock.theme:
Windsock[...], Windsock.fetch, Windsock.color, Windsock.color!, Windsock.colors,
Windsock.scale, Windsock.scales, Windsock.scale_names
```

## Scale API

`scale(:brand)` returns a `Windsock::Scale`. It acts like a Hash of step => Color and prints as a table in the console, so you can see at a glance which steps work as text or background. In a terminal, ratios that meet AA (4.5:1) are green and the rest red; `scale.table(level: :aaa)` raises the bar, `scale.table(color: false)` turns the ANSI off.

```
>> Windsock.scale(:brand)
#<Windsock::Scale brand (11 steps; contrast vs white #ffffff / black #000000; AA needs 4.5:1; text = what to write on it)
  step  hex         white   black  text
    50  #eff6ff      1.09   19.27  black
   100  #dbeafe      1.22   17.22  black
   ...
   500  #2b7fff      3.76    5.58  black
   600  #155dfc      5.26    4.00  white
   ...
   950  #162456     14.72    1.43  white
>
```

```ruby
scale = Windsock.scale(:brand)

scale[500]                             # Color (also scale["500"], scale[:muted])
scale.fetch(500)                       # raises Windsock::NotFound if missing
scale.steps                            # [50, 100, ..., 950, "muted"]
scale.each { |step, color| ... }       # Enumerable over [step, color]
scale.to_h                             # plain Hash

scale.contrast(:white)                 # { 50 => 1.09, ..., 950 => 14.72 } — WCAG ratios
scale.accessible(on: :white)           # steps usable as text on white (AA, 4.5:1), as a Scale
scale.accessible(on: "#000", level: :aaa)
scale.text_colors                      # { 50 => black, ..., 950 => white } — text to put on each step
scale.white, scale.black               # what "white" and "black" mean here
```

"White" and "black" are the theme's `--color-white` / `--color-black`. Tailwind ships them as `#fff` / `#000`, but an app that softens white to `#f5f5f5` gets its contrast measured against `#f5f5f5`, and the table title says so. `on:` also takes any theme color name (`scale.contrast(:surface)`) before falling back to CSS parsing.

Levels are `:aa` (4.5:1), `:aa_large` (3:1, 18pt+ or 14pt bold), `:aaa` (7:1) and `:aaa_large` (4.5:1). Contrast ignores alpha: a translucent color is rated as if opaque.

`color(:brand)` also returns the scale when the theme has `--color-brand-*` steps but no bare `--color-brand`. An exact `--color-brand` always wins. The view helpers want one color, so `tailwind_color(:brand)` raises `ArgumentError` naming the steps instead.

## Color API

```ruby
c = Windsock.color(:brand, 500)
c.to_hex            # "#2b7fff" ("#2b7fff80" when alpha < 1)
c.to_hex(alpha: false)
c.to_rgb            # "rgb(43 127 255)"
c.to_rgba           # "rgba(43, 127, 255, 1)"
c.rgb               # [43, 127, 255]
c.alpha             # 1.0
c.source            # "oklch(62.3% 0.214 259.815)"
c.luminance         # WCAG relative luminance
c.contrast("#fff")  # WCAG contrast ratio (any CSS color, a Color, or :white / :black)
c.accessible?("#fff")                 # contrast >= 4.5 (AA for normal text)
c.accessible?(:white, level: :aaa)    # :aa, :aa_large, :aaa, :aaa_large
c.aa?("#fff") / c.aaa?("#fff", large: true)
c.contrast_level("#fff")              # :aaa, :aa, :aa_large or nil
c.text_color        # Windsock::Color::BLACK or ::WHITE, whichever reads better on c
c.text_color(white: theme.white, black: theme.black)   # same, with the theme's own
c.dark?             # same question as a boolean

Windsock::Color.parse("hsl(217 91% 60%)")  # any CSS color
```

Parses hex, named colors, `rgb()`, `hsl()`, `oklch()`, `oklab()`, `color(srgb ...)` and Tailwind's `--alpha(color / 50%)`.

Colors outside the sRGB gamut (several of Tailwind's v4 defaults are) are gamut-mapped the way CSS Color 4 and browsers do it, so the hex values match what the Tailwind docs and DevTools show.

## What it understands

- `@theme`, `@theme inline`, `@theme static`, `@theme reference`, `@theme default`, with Tailwind's precedence rules
- `@import "tailwindcss"` and `@import "tailwindcss/theme.css"` → bundled copy of Tailwind's default theme (currently v4.3.3, see `Windsock::TAILWIND_VERSION`)
- Relative `@import "./partials/brand.css"` (missing files raise `Windsock::ImportError`)
- `--color-blue-*: initial` and `--*: initial` resets
- `var(--x)`, `var(--x, fallback)`, `--theme(--x, initial)`
- Comments, multi-line values, `@keyframes` inside `@theme`

## What it doesn't

- **Tailwind v3** `tailwind.config.js`. The theme lives in JavaScript; you need Node for that.
- **Plugins** (`@plugin "daisyui"`) that register their own theme values.
- **Dark mode / variant overrides.** Values set in `.dark { --color-surface: ... }` aren't theme variables. You get the `@theme` value.
- **Bare imports** from `node_modules` are skipped silently.

## Development

```
bin/setup
bundle exec rake        # tests + rubocop
bin/console
```

To bump the bundled Tailwind theme: copy `theme.css` from the `tailwindcss` npm package into `lib/windsock/tailwind/` and update `Windsock::TAILWIND_VERSION`.

## License

MIT. The bundled `theme.css` is from [Tailwind CSS](https://github.com/tailwindlabs/tailwindcss), also MIT.
