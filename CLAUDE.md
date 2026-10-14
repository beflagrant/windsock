# CLAUDE.md

Windsock is a Ruby gem that reads a Tailwind v4 stylesheet (`@theme { --color-brand-500: ... }`) and exposes the tokens to Ruby: resolved values, `Color` objects with hex/rgb conversion, color `Scale`s with WCAG contrast, and Rails view helpers. No Node, no runtime gem dependencies. Public API is documented in [README.md](README.md); keep it in sync when the API changes.

## Commands

```
bin/setup                                              # bundle install
bundle exec rake                                       # tests + rubocop (what CI runs)
bundle exec rake test                                  # tests only
bundle exec rubocop -a                                 # lint + autocorrect
bundle exec ruby -Ilib -Itest test/test_color.rb       # one file
bundle exec ruby -Ilib -Itest test/test_color.rb -n test_name   # one test
bin/console                                            # irb with windsock loaded
```

CI ([.github/workflows/main.yml](.github/workflows/main.yml)) runs `bundle exec rake` on Ruby 3.2, 3.3, 3.4 and 4.0. Minimum Ruby is 3.2, so don't use syntax newer than that.

## Architecture

Pipeline: CSS text → `Parser` → flat `{ "color-brand-500" => "oklch(...)" }` hash → `Theme` (lookup + `var()` resolution) → `Color` / `Scale`.

- [lib/windsock.rb](lib/windsock.rb): module entry point. Error classes (`Error`, `ParseError`, `ImportError`, `NotFound`), `TAILWIND_VERSION`, memoized `Windsock.theme` (from `Windsock.path`), `reset!`, `default_theme`, and module-level shortcuts delegating to `theme`. Loads the Railtie only when `Rails::Railtie` is defined.
- [lib/windsock/parser.rb](lib/windsock/parser.rb): collects `--*` declarations from top-level `@theme` blocks and follows `@import`s. Contains a hand-written `Scanner` tokenizer (strings, parens, nested braces) instead of a CSS library.
  - `@import "tailwindcss"` / `"tailwindcss/theme(.css)"` loads the bundled [lib/windsock/tailwind/theme.css](lib/windsock/tailwind/theme.css). Relative/absolute imports resolve to `path`, `path.css` or `path/index.css`, or raise `ImportError`. Bare specifiers are ignored silently.
  - Precedence: `@theme default` values never override keys set by a non-default `@theme` (tracked in `@owned`). `--x: initial`, `--ns-*: initial` and `--*: initial` delete keys.
  - `files` tracks parsed paths, which also prevents import cycles.
- [lib/windsock/theme.rb](lib/windsock/theme.rb): immutable var map. Keys have no leading `--`; lookups accept a full key or parts (`theme[:color, :brand, 500]` joins with `-`). `#[]` resolves `var()` / `--theme()` lazily with memoization and a depth limit of 20; `#raw` returns the value as written. `NAMESPACES` generates `fonts`, `breakpoints`, etc. via `define_method`. `color(:brand)` returns a `Scale` when there's no exact `--color-brand` but `brand-<n>` steps exist. `white`/`black` come from the theme's `--color-white`/`--color-black`, falling back to pure values.
- [lib/windsock/color.rb](lib/windsock/color.rb): parses CSS colors (hex, named, rgb, hsl, oklch, oklab, `color(srgb ...)`, `--alpha()`) into gamma-encoded sRGB floats + alpha, keeping `source`. Out-of-gamut OKLCH/OKLab colors are gamut-mapped per CSS Color 4 (chroma reduction with `JND`), so hex output matches browsers and the Tailwind docs. WCAG luminance/contrast lives here (`WCAG` thresholds; contrast ignores alpha). `Color.parse` returns nil on failure; `parse!` raises.
- [lib/windsock/scale.rb](lib/windsock/scale.rb): Enumerable step → Color map for one color family. Numeric steps are Integer keys, others (`muted`) stay Strings. Contrast is measured against the owning theme's white/black. `inspect`/`table` print an ANSI contrast table for the console.
- [lib/windsock/helper.rb](lib/windsock/helper.rb): `tailwind_color`, `tailwind_text_color`, `tailwind_scale`, `tailwind_value`, `tailwind_theme`. Formats: `:hex`, `:rgb`, `:rgba`, `:css`. Raises `ArgumentError` if given a scale instead of a single color.
- [lib/windsock/railtie.rb](lib/windsock/railtie.rb): sets `Windsock.path` (from `config.windsock.path`, default `app/assets/tailwind/application.css`), includes `Helper` into ActionView, and in reloading environments watches `*.css` in the stylesheet's directory to call `Windsock.reset!`. Rails is not a dependency and there are no Rails tests, so changes here need care.

## Tests

Minitest, one file per class in [test/](test/). Fixtures in [test/fixtures/](test/fixtures/): `application.css` imports `tailwindcss` and `partials/brand.css`, resets the blue scale, and defines a `brand` scale and a `3xl` breakpoint, so many assertions use Tailwind's real default values (e.g. brand-500 is `#2b7fff`). Use `fixture("name.css")` from `test_helper.rb`. Tests that set `Windsock.path` should call `Windsock.reset!`.

## Conventions

- Every file starts with `# frozen_string_literal: true`. Double-quoted strings, max line length 120 ([.rubocop.yml](.rubocop.yml)). Short single-letter params (`r`, `g`, `b`, `l`) are allowed for color math.
- Comments explain *why* and give one-line usage examples above public methods; match that density.
- Lookup methods come in pairs: a nil-returning form (`[]`, `color`) and a raising form (`fetch`, `color!`) that raises `Windsock::NotFound`.
- User-visible changes get a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md). Commits use Conventional Commits (`feat:`, `chore:`, ...).
- Updating the bundled Tailwind theme: copy `theme.css` (and `LICENSE` if changed) from the `tailwindcss` npm package into `lib/windsock/tailwind/`, then bump `Windsock::TAILWIND_VERSION`. Expect color assertions in tests to change if Tailwind changed its palette.
- The gem ships `git ls-files` minus `bin/`, `test/`, `.github/` and dev config ([windsock.gemspec](windsock.gemspec)); new runtime files must be committed to be packaged.

## Out of scope (by design)

Tailwind v3 JS configs, plugin-registered theme values, dark-mode/variant overrides outside `@theme`, and `node_modules` imports. See "What it doesn't" in the README before adding any of these.
