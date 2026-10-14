# frozen_string_literal: true

require "test_helper"

class TestTheme < Minitest::Test
  def setup
    @theme = Windsock.load(fixture("application.css"))
  end

  def test_lookup_forms
    assert_equal "120rem", @theme["breakpoint-3xl"]
    assert_equal "120rem", @theme[:breakpoint, "3xl"]
    assert_equal "120rem", @theme[:breakpoint_3xl.to_s.tr("_", "-")]
    assert_equal "0.875rem", @theme[:text, :sm]
    assert_nil @theme[:nope]
    assert_raises(Windsock::NotFound) { @theme.fetch(:nope) }
  end

  def test_defaults_merged_with_app_theme
    assert_equal "40rem", @theme.breakpoints["sm"]
    assert_equal "120rem", @theme.breakpoints["3xl"]
    assert @theme.key?(:color, :red, 500)
    refute @theme.key?(:color, :blue, 500), "blue scale was reset with initial"
    assert @theme.key?(:color, :brand, 500)
  end

  def test_color
    assert_equal "#2b7fff", @theme.color(:brand, 500).to_hex
    assert_equal "#2b7fff", @theme.color("brand-500").to_hex
    assert_equal "#1e3a8a", @theme.color(:brand, 900).to_hex
    assert_nil @theme.color(:blue, 500)
    assert_nil @theme.color(:current)
    assert_raises(Windsock::NotFound) { @theme.color!(:blue, 500) }
  end

  def test_color_family_returns_scale
    scale = @theme.color(:brand)
    assert_kind_of Windsock::Scale, scale
    assert_equal @theme.scale(:brand), scale
    assert_equal @theme.scale(:red), @theme.color!("red")
    assert_nil @theme.color(:blue), "reset scale is not a family"
    assert_nil @theme.color(:nope)
    assert_raises(Windsock::NotFound) { @theme.color!(:nope) }
  end

  def test_white_black_and_text_color
    assert_equal "#ffffff", @theme.white.to_hex, "bundled Tailwind default"
    assert_equal "#000000", @theme.black.to_hex
    assert_equal @theme.white, @theme.text_color(:brand, 900)
    assert_equal @theme.black, @theme.text_color(:brand, 50)
    assert_raises(Windsock::NotFound) { @theme.text_color(:brand) }
    assert_raises(Windsock::NotFound) { @theme.text_color(:nope) }

    soft = Windsock.parse("@theme { --color-white: #f5f5f5; --color-ink: #101010; }")
    assert_equal "#f5f5f5", soft.white.to_hex
    assert_equal "#000000", soft.black.to_hex, "falls back to pure black"
    assert_equal "#f5f5f5", soft.text_color(:ink).to_hex
  end

  def test_exact_color_beats_scale
    theme = Windsock.parse("@theme { --color-brand: #123456; --color-brand-500: #2b7fff; }")
    assert_kind_of Windsock::Color, theme.color(:brand)
    assert_equal "#123456", theme.color(:brand).to_hex
    assert_equal ["brand"], theme.scale_names
  end

  def test_var_resolution
    assert_equal "oklch(62.3% 0.214 259.815)", @theme[:color, :primary]
    assert_equal "#2b7fff", @theme.color(:primary).to_hex
    assert_equal "#ffffff", @theme.color(:primary, :fg).to_hex
    assert_equal "#fafafa", @theme.color(:surface).to_hex, "fallback used when var missing"
    assert_equal "#00000080", @theme.color(:overlay).to_hex, "--alpha() over var()"
    assert_equal "oklch(82.8% 0.189 84.429)", @theme[:color, :accent], "@theme inline"
  end

  def test_raw_keeps_var
    assert_equal "var(--color-brand-500)", @theme.raw(:color, :primary)
  end

  def test_unresolvable_var_left_alone
    theme = Windsock.parse("@theme { --color-x: var(--color-nope); }")
    assert_equal "var(--color-nope)", theme[:color, :x]
    assert_nil theme.color(:x)
  end

  def test_cyclic_var_terminates
    theme = Windsock.parse("@theme { --color-a: var(--color-b); --color-b: var(--color-a); }")
    assert_kind_of String, theme[:color, :a]
  end

  def test_theme_function
    theme = Windsock.parse(<<~CSS)
      @theme { --font-sans: Inter; --default-font-family: --theme(--font-sans, initial); }
    CSS
    assert_equal "Inter", theme["default-font-family"]
    assert_equal "Inter", theme.fonts["sans"]
  end

  def test_namespaces
    assert_equal "Satoshi", @theme.fonts["display"][/Satoshi/]
    assert_includes @theme.fonts.keys, "sans"
    assert_equal "0.5rem", @theme.radii["lg"]
    assert_equal "wiggle 1s ease-in-out infinite", @theme.animations["wiggle"]
    assert_equal "calc(1.25 / 0.875)", @theme.text_sizes["sm--line-height"]
    assert_match(/rgb/, @theme.shadows["card"])
  end

  def test_colors_and_scale
    colors = @theme.colors
    assert_kind_of Windsock::Color, colors["brand-500"]
    refute colors.key?("current")

    scale = @theme.scale(:brand)
    assert_equal [50, 500, 900, "muted"], scale.keys
    assert_equal "#2b7fff", scale[500].to_hex
    assert_equal 11, @theme.scale(:red).size
  end

  def test_spacing
    assert_equal "0.25rem", @theme.spacing
    assert_equal "1rem", @theme.spacing(4)
    assert_equal "0.125rem", @theme.spacing(0.5)
    assert_equal "1.5rem", @theme.spacing(:gutter)
  end

  def test_to_h_is_resolved
    assert_equal "oklch(62.3% 0.214 259.815)", @theme.to_h["color-primary"]
  end

  def test_files
    assert_equal 3, @theme.files.size
  end

  def test_without_tailwind_import
    theme = Windsock.load(fixture("no_import.css"))
    assert_equal %w[color-ink color-red-500], theme.keys
  end

  def test_default_theme
    assert_equal "#2b7fff", Windsock.default_theme.color(:blue, 500).to_hex
    assert_operator Windsock.default_theme.colors.size, :>, 250
  end
end
