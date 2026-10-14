# frozen_string_literal: true

require "test_helper"

class TestParser < Minitest::Test
  Parser = Windsock::Parser

  def test_reads_theme_declarations
    vars = Parser.parse(<<~CSS).vars
      @theme {
        --color-brand: #f00;
        --font-display: "Satoshi", sans-serif;
      }
    CSS
    assert_equal({ "color-brand" => "#f00", "font-display" => '"Satoshi", sans-serif' }, vars)
  end

  def test_multiline_values_and_missing_trailing_semicolon
    vars = Parser.parse(<<~CSS).vars
      @theme {
        --font-sans:
          ui-sans-serif, system-ui,
          sans-serif;
        --radius-lg: 0.5rem
      }
    CSS
    assert_equal "ui-sans-serif, system-ui, sans-serif", vars["font-sans"]
    assert_equal "0.5rem", vars["radius-lg"]
  end

  def test_strips_comments_and_skips_other_rules
    vars = Parser.parse(<<~CSS).vars
      /* @theme { --color-fake: red; } */
      @layer base { body { color: red; } }
      .dark { --color-x: #000; }
      @media (min-width: 40rem) { .a { --color-y: #fff; } }
      @theme { --color-real: blue; /* inline comment */ }
    CSS
    assert_equal({ "color-real" => "blue" }, vars)
  end

  def test_skips_keyframes_inside_theme
    vars = Parser.parse(<<~CSS).vars
      @theme {
        --animate-spin: spin 1s linear infinite;
        @keyframes spin { to { transform: rotate(360deg); } }
        --animate-ping: ping 1s;
      }
    CSS
    assert_equal %w[animate-spin animate-ping], vars.keys
  end

  def test_theme_options_are_accepted
    vars = Parser.parse(<<~CSS).vars
      @theme inline reference { --color-a: red; }
      @theme static { --color-b: blue; }
      @theme prefix(tw) { --color-c: green; }
    CSS
    assert_equal %w[color-a color-b color-c], vars.keys
  end

  def test_default_never_overrides_user_values
    vars = Parser.parse(<<~CSS).vars
      @theme { --color-red-500: #111; }
      @theme default { --color-red-500: #222; --color-red-600: #333; }
      @theme default { --color-red-600: #444; }
      @theme { --color-red-600: #555; }
    CSS
    assert_equal({ "color-red-500" => "#111", "color-red-600" => "#555" }, vars)
  end

  def test_initial_resets
    vars = Parser.parse(<<~CSS).vars
      @theme default {
        --color-red-500: red;
        --color-red-600: darkred;
        --color-blue-500: blue;
        --font-sans: sans-serif;
      }
      @theme {
        --color-red-*: initial;
        --color-red-500: crimson;
        --font-sans: initial;
      }
    CSS
    assert_equal({ "color-blue-500" => "blue", "color-red-500" => "crimson" }, vars)
  end

  def test_star_wipes_everything
    vars = Parser.parse(<<~CSS).vars
      @theme default { --color-red-500: red; --font-sans: x; }
      @theme { --*: initial; --color-ink: #000; }
    CSS
    assert_equal({ "color-ink" => "#000" }, vars)
  end

  def test_import_tailwindcss_loads_bundled_theme
    parser = Parser.parse('@import "tailwindcss";')
    assert_equal "oklch(62.3% 0.214 259.815)", parser.vars["color-blue-500"]
    assert_equal "40rem", parser.vars["breakpoint-sm"]
    assert_includes parser.files, Windsock.default_theme_path
  end

  def test_import_with_modifiers
    parser = Parser.parse('@import "tailwindcss" source(none) prefix(tw) theme(static);')
    assert parser.vars.key?("color-blue-500")
  end

  def test_tailwind_subpath_imports
    assert Parser.parse('@import "tailwindcss/theme.css" layer(theme);').vars.key?("color-blue-500")
    assert_empty Parser.parse('@import "tailwindcss/utilities" layer(utilities);').vars
  end

  def test_relative_import
    parser = Parser.parse_file(fixture("application.css"))
    assert_equal "#1e3a8a", parser.vars["color-brand-900"]
    assert_includes parser.files, fixture("partials/brand.css")
  end

  def test_missing_relative_import_raises
    assert_raises(Windsock::ImportError) do
      Parser.parse('@import "./nope.css";', base_dir: fixture_dir)
    end
  end

  def test_bare_imports_ignored
    assert_empty Parser.parse('@import "tw-animate-css"; @import url("https://x/y.css");').vars
  end

  def test_strings_with_braces_and_semicolons
    vars = Parser.parse(<<~CSS).vars
      .x::before { content: "}; @theme { --color-fake: red; }"; }
      @theme { --font-weird: "a;b{c}"; --color-ok: #000; }
    CSS
    assert_equal({ "font-weird" => '"a;b{c}"', "color-ok" => "#000" }, vars)
  end
end
