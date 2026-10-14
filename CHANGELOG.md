## [Unreleased]

- `Theme#scale` returns a `Windsock::Scale` instead of a Hash. It still answers
  `[]`, `keys`, `size`, `each` and `to_h`, prints as a contrast table in the console,
  and adds `contrast(on)`, `accessible(on:, level:)`, `text_colors` and `table(level:, color:)`
  (passing ratios green, failing red when stdout is a TTY).
- `Theme#scales` and `Theme#scale_names`; `Windsock.colors`, `.scale`, `.scales`,
  `.scale_names` shortcuts.
- `Color#accessible?`, `#aa?`, `#aaa?`, `#contrast_level`, `#text_color`, `#name`;
  `Color::WHITE` / `Color::BLACK`. `#contrast` accepts any Color or CSS color.
- `tailwind_text_color` and `tailwind_scale` view helpers.
- `Theme#white`, `#black` and `#text_color`. Scales measure contrast against the
  theme's `--color-white` / `--color-black`, not pure `#fff` / `#000`; `on:` accepts
  theme color names. `Color#text_color` takes `white:` / `black:`.
- `color(:brand)` returns the brand `Scale` when the theme has `brand-*` steps but no
  bare `--color-brand`, instead of `nil`. `tailwind_color(:brand)` raises `ArgumentError`
  listing the steps. `Theme#colors` and `#scale_names` are memoized.

## [0.1.0] - 2026-10-13

- Initial release: parse Tailwind v4 `@theme` blocks, resolve `@import` and `var()`,
  convert oklch/oklab/hsl/rgb colors to hex with CSS Color 4 gamut mapping,
  Rails helper `tailwind_color` with dev reload.
