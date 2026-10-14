## [Unreleased]

## [0.1.0] - 2026-10-14

Initial release.

- Parse Tailwind v4 `@theme` blocks with Tailwind's precedence rules; resolve `@import`
  (including a bundled copy of Tailwind's default theme), `var()` and `--theme()`.
- Convert oklch/oklab/hsl/rgb/hex/named colors to hex, `rgb()` and `rgba()`, with CSS
  Color 4 gamut mapping.
- `Theme` lookups: `#color`, `#colors`, `#scale`, `#scales`, `#scale_names`,
  `#breakpoints`, `#fonts`, `#spacing` and the other namespaces; `#white`, `#black`
  and `#text_color` use the theme's own `--color-white` / `--color-black`.
- `color(:brand)` returns the brand `Scale` when the theme has `brand-*` steps but no
  bare `--color-brand`.
- `Windsock::Scale`: Hash-like steps that print as a WCAG contrast table in the console,
  plus `contrast(on)`, `accessible(on:, level:)`, `text_colors` and `table(level:, color:)`.
- WCAG helpers on `Color`: `#contrast`, `#accessible?`, `#aa?`, `#aaa?`,
  `#contrast_level` (`:aaa`, `:aa`, `:aa_large` or `:fail`), `#text_color`, `#dark?`, `#name`;
  `Color::WHITE` / `Color::BLACK`.
- Rails: Railtie with dev reload, and `tailwind_color`, `tailwind_text_color`,
  `tailwind_scale` and `tailwind_value` view helpers.
