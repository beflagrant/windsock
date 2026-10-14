# frozen_string_literal: true

require "test_helper"
require "stringio"

class TestScale < Minitest::Test
  def setup
    @theme = Windsock.load(fixture("application.css"))
    @brand = @theme.scale(:brand)
  end

  def test_hash_like_access
    assert_equal "brand", @brand.name
    assert_equal [50, 500, 900, "muted"], @brand.steps
    assert_equal "#2b7fff", @brand[500].to_hex
    assert_equal "#2b7fff", @brand["500"].to_hex
    assert_equal "#2b7fff", @brand[:"500"].to_hex
    assert_equal "#1e3a8a", @brand.fetch(900).to_hex
    assert_kind_of Windsock::Color, @brand[:muted]
    assert_nil @brand[300]
    assert_raises(Windsock::NotFound) { @brand.fetch(300) }
    assert @brand.step?(50)
    assert_equal 4, @brand.size
    assert_equal @brand.steps, @brand.to_h.keys
    assert_equal [50, 500], @brand.first(2).map(&:first), "Enumerable over [step, color]"
  end

  def test_contrast
    ratios = @brand.contrast(:white)
    assert_in_delta 1.09, ratios[50], 0.01
    assert_in_delta 3.76, ratios[500], 0.01
    assert_in_delta 10.36, ratios[900], 0.01
    assert_in_delta 1.0, @brand.contrast(@brand[50])[50], 0.01
  end

  def test_accessible
    assert_equal [900], @brand.accessible(on: :white).steps
    assert_equal [500, 900], @brand.accessible(on: :white, level: :aa_large).steps
    assert_equal [50, 500, "muted"], @brand.accessible(on: "#000").steps
    assert_equal "brand", @brand.accessible.name
    assert_kind_of Windsock::Scale, @brand.accessible
    assert_equal [900], @brand.accessible(on: :white, level: :aaa).steps
    assert @theme.scale(:nope).accessible.empty?
  end

  def test_text_colors
    text = @brand.text_colors
    assert_equal "#000000", text[50].to_hex
    assert_equal "#000000", text[500].to_hex, "blue-500 is just light enough for black text (5.58 vs 3.76)"
    assert_equal "#ffffff", text[900].to_hex
  end

  def test_inspect_is_a_table
    out = @brand.table(color: false)
    assert_equal out, @brand.inspect unless $stdout.tty?
    assert_includes out, "#<Windsock::Scale brand (4 steps; contrast vs white #ffffff / black #000000; AA needs 4.5:1;"
    assert_includes @brand.table(level: :aaa, color: false), "AAA needs 7.0:1"
    assert_raises(ArgumentError) { @brand.table(level: :aaaa) }
    assert_match(/^\s+step\s+hex\s+white\s+black\s+text$/, out)
    assert_match(/^\s+500\s+#2b7fff\s+3\.76\s+5\.58\s+black$/, out)
    assert_match(/^\s+900\s+#1e3a8a\s+10\.36\s+2\.03\s+white$/, out)
    assert_equal "#<Windsock::Scale nope (empty)>", @theme.scale(:nope).inspect
    assert_equal "brand: 50=#eff6ff 500=#2b7fff 900=#1e3a8a muted=#99adcccc", @brand.to_s
  end

  def test_table_colors_ratios_by_level
    out = @brand.table(color: true)
    assert_includes out, "\e[31m  3.76\e[0m", "500 on white fails AA, red"
    assert_includes out, "\e[32m  5.58\e[0m", "500 on black passes AA, green"
    assert_includes out, "\e[32m 10.36\e[0m"
    refute_includes @brand.table(color: false), "\e["

    aaa = @brand.table(level: :aaa, color: true)
    assert_includes aaa, "\e[31m  5.58\e[0m", "AAA needs 7"
    assert_includes aaa, "\e[32m 10.36\e[0m"
  end

  def test_pretty_print_hands_pp_the_table_verbatim
    assert_equal "#{@brand.table}\n", @brand.pretty_inspect
  end

  def test_irb_color_printer_keeps_cell_colors
    require "irb/color_printer"
    with_tty_stdout do
      out = +""
      IRB::ColorPrinter.pp(@brand, out, 79, colorize: true)
      assert_equal "#{@brand.table(color: true)}\n", out
      refute_includes out, "\e[32m#<", "IRB must not wrap the table in its own green"
      refute_includes out, "^[", "ANSI must not be escaped for print"
    end
  rescue LoadError
    skip "irb not available"
  end

  def test_white_and_black_come_from_the_theme
    theme = Windsock.parse(<<~CSS)
      @theme {
        --color-white: #f5f5f5;
        --color-black: #111111;
        --color-surface: #e0e0e0;
        --color-ink-500: #8a8a8a;
        --color-ink-900: #101010;
      }
    CSS
    ink = theme.scale(:ink)
    assert_equal "#f5f5f5", ink.white.to_hex
    assert_equal "#111111", ink.black.to_hex

    assert_equal ink[500].contrast("#f5f5f5").round(2), ink.contrast(:white)[500]
    refute_equal ink[500].contrast("#ffffff").round(2), ink.contrast(:white)[500]
    assert_equal ink[500].contrast("#111111").round(2), ink.contrast("black")[500]
    assert_equal ink[500].contrast("#e0e0e0").round(2), ink.contrast(:surface)[500], "theme name resolves"
    assert_equal 1.0, ink.contrast("ink-500")[500]
    assert_equal ink[500].contrast("#ff0000").round(2), ink.contrast("red")[500], "falls back to CSS"

    assert_equal "#f5f5f5", ink.text_colors[900].to_hex
    assert_equal "#111111", ink.text_colors[500].to_hex
    assert_equal [900], ink.accessible(on: :white).steps
    assert_equal "#f5f5f5", ink.accessible(on: :white).white.to_hex, "theme survives filtering"

    table = ink.table(color: false)
    assert_includes table, "contrast vs white #f5f5f5 / black #111111"
    assert_match(/^\s+900\s+#101010\s+[\d.]+\s+[\d.]+\s+white$/, table)
    assert_match(/^\s+500\s+#8a8a8a\s+[\d.]+\s+[\d.]+\s+black$/, table)
  end

  def test_scale_without_theme_uses_pure_white_and_black
    bare = Windsock::Scale.new(:x, { 500 => "#767676" })
    assert_equal Windsock::Color::WHITE, bare.white
    assert_equal bare[500].contrast("#fff").round(2), bare.contrast(:white)[500]
  end

  def test_equality
    assert_equal @brand, @theme.scale("brand")
    refute_equal @brand, @theme.scale(:red)
  end

  def test_scale_names
    names = @theme.scale_names
    assert_includes names, "brand"
    assert_includes names, "red"
    refute_includes names, "blue"
    refute_includes names, "primary"
    assert_equal names, @theme.scales.keys
  end

  def test_theme_scales
    scales = @theme.scales
    assert_includes scales.keys, "brand"
    assert_includes scales.keys, "red"
    refute_includes scales.keys, "blue", "reset with initial"
    refute_includes scales.keys, "primary", "no numeric steps"
    assert_equal @brand, scales["brand"]
    assert_equal 11, scales["red"].size
  end

  private

  def with_tty_stdout
    original = $stdout
    $stdout = StringIO.new
    $stdout.define_singleton_method(:tty?) { true }
    yield
  ensure
    $stdout = original
  end
end
