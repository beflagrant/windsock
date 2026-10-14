# frozen_string_literal: true

require "test_helper"

class TestColor < Minitest::Test
  Color = Windsock::Color

  def test_hex_forms
    assert_equal "#ffffff", Color.parse("#fff").to_hex
    assert_equal "#3b82f6", Color.parse("#3B82F6").to_hex
    assert_equal "#3b82f680", Color.parse("#3b82f680").to_hex
    assert_equal "#3b82f6", Color.parse("#3b82f680").to_hex(alpha: false)
    assert_equal "#aabbccdd", Color.parse("#abcd").to_hex
  end

  def test_named
    assert_equal "#ff0000", Color.parse("red").to_hex
    assert_equal "#663399", Color.parse("RebeccaPurple").to_hex
    assert_equal "#00000000", Color.parse("transparent").to_hex
    assert_equal 0.0, Color.parse("transparent").alpha
  end

  def test_rgb_forms
    assert_equal "#3b82f6", Color.parse("rgb(59 130 246)").to_hex
    assert_equal "#3b82f6", Color.parse("rgb(59, 130, 246)").to_hex
    assert_equal "#3b82f680", Color.parse("rgba(59, 130, 246, 0.5)").to_hex
    assert_equal "#3b82f680", Color.parse("rgb(59 130 246 / 50%)").to_hex
    assert_equal "#ff0000", Color.parse("rgb(100% 0% 0%)").to_hex
  end

  def test_hsl_forms
    assert_equal "#ff0000", Color.parse("hsl(0 100% 50%)").to_hex
    assert_equal "#00ff00", Color.parse("hsl(120deg, 100%, 50%)").to_hex
    assert_equal "#0000ff", Color.parse("hsl(0.6667turn 100% 50%)").to_hex
    assert_equal "#808080", Color.parse("hsl(0 0% 50.2%)").to_hex
  end

  def test_oklch_matches_tailwind_palette
    # Hex values as shown in the Tailwind v4 docs color reference. Several
    # are outside sRGB and rely on gamut mapping; allow one step per channel.
    {
      "oklch(62.3% 0.214 259.815)" => "#2b7fff", # blue-500
      "oklch(63.7% 0.237 25.331)" => "#fb2c36",  # red-500
      "oklch(72.3% 0.219 149.579)" => "#00c950", # green-500
      "oklch(70.5% 0.213 47.604)" => "#ff6900",  # orange-500
      "oklch(21% 0.034 264.665)" => "#101828",   # gray-900
      "oklch(98.4% 0.003 247.858)" => "#f8fafc", # slate-50
      "oklch(14.1% 0.005 285.823)" => "#09090b"  # zinc-950
    }.each do |oklch, hex|
      assert_close hex, Color.parse(oklch), oklch
    end
  end

  def test_oklch_extremes_and_alpha
    assert_equal "#000000", Color.parse("oklch(0% 0 0)").to_hex
    assert_equal "#ffffff", Color.parse("oklch(100% 0 0)").to_hex
    assert_equal "#ffffff", Color.parse("oklch(1 0 0)").to_hex
    assert_equal "#2b7fff80", Color.parse("oklch(62.3% 0.214 259.815 / 0.5)").to_hex
    assert_equal "#2b7fff80", Color.parse("oklch(0.623 0.214 259.815 / 50%)").to_hex
  end

  def test_oklab
    assert_close "#2b7fff", Color.parse("oklab(0.623 -0.0378 -0.2106)")
  end

  def test_color_srgb
    assert_equal "#3b82f6", Color.parse("color(srgb 0.231 0.51 0.965)").to_hex
  end

  def test_alpha_function
    assert_equal "#00000080", Color.parse("--alpha(#000 / 50%)").to_hex
    assert_equal "#3b82f640", Color.parse("--alpha(rgb(59 130 246 / 50%) / 0.5)").to_hex
  end

  def test_unparseable
    assert_nil Color.parse("currentColor")
    assert_nil Color.parse("var(--color-x)")
    assert_nil Color.parse("")
    assert_raises(Windsock::ParseError) { Color.parse!("nope") }
  end

  def test_outputs
    color = Color.parse("rgb(59 130 246 / 0.5)")
    assert_equal [59, 130, 246], color.rgb
    assert_equal "rgb(59 130 246 / 0.5)", color.to_rgb
    assert_equal "rgba(59, 130, 246, 0.5)", color.to_rgba
    assert_equal "rgb(59 130 246)", Color.parse("#3b82f6").to_rgb
    assert_equal "rgba(59, 130, 246, 1)", Color.parse("#3b82f6").to_rgba
    assert_equal "#3b82f6", Color.parse("#3b82f6").to_s
  end

  def test_luminance_and_contrast
    assert_in_delta 1.0, Color.parse("white").luminance, 0.001
    assert_in_delta 0.0, Color.parse("black").luminance, 0.001
    assert_in_delta 21.0, Color.parse("white").contrast("black"), 0.01
    assert_predicate Color.parse("#1e3a8a"), :dark?
    assert_predicate Color.parse("#fef3c7"), :light?
  end

  def test_equality
    assert_equal Color.parse("#fff"), Color.parse("white")
    assert_equal 1, [Color.parse("#fff"), Color.parse("rgb(255 255 255)")].uniq.size
  end

  private

  def assert_close(expected, color, label = expected)
    want = expected.delete("#").scan(/../).map(&:hex)
    got = color.rgb
    want.zip(got).each_with_index do |(w, g), i|
      assert_operator (w - g).abs, :<=, 1, "#{label}: channel #{i} expected #{w}, got #{g} (#{color.to_hex})"
    end
  end

  def test_wcag_levels
    blue = Color.parse("#2b7fff")
    assert blue.accessible?("#fff", level: :aa_large)
    refute blue.accessible?("#fff")
    assert blue.accessible?(:black)
    assert blue.aa?(Color.parse("black"))
    assert blue.aa?("#fff", large: true)
    refute blue.aaa?("#000")
    assert_equal :aa_large, blue.contrast_level("#fff")
    assert_equal :aa, blue.contrast_level("#000")
    assert_equal :aaa, Color.parse("#000").contrast_level("#fff")
    assert_equal :fail, Color.parse("#eee").contrast_level("#fff")
    assert_raises(ArgumentError) { blue.accessible?("#fff", level: :aaaa) }
  end

  def test_text_color
    assert_equal Color::WHITE, Color.parse("#1e3a8a").text_color
    assert_equal Color::BLACK, Color.parse("#eff6ff").text_color
    assert_equal Color::BLACK, Color.parse("#2b7fff").text_color, "5.58 on black beats 3.76 on white"
    soft = Color.parse("#f5f5f5")
    assert_equal soft, Color.parse("#1e3a8a").text_color(white: soft)
    assert_equal Color::BLACK, Color.parse("#ffffff").text_color(white: soft)
    assert_equal "white", Color::WHITE.name
    assert_equal "#2b7fff", Color.parse("#2b7fff").name
  end
end
