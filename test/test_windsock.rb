# frozen_string_literal: true

require "test_helper"

class TestWindsock < Minitest::Test
  include Windsock::Helper

  def setup
    Windsock.path = fixture("application.css")
    Windsock.reset!
  end

  def teardown
    Windsock.path = nil
    Windsock.reset!
  end

  def test_version
    refute_nil Windsock::VERSION
    assert_match(/\A4\./, Windsock::TAILWIND_VERSION)
  end

  def test_module_delegates
    assert_equal "#2b7fff", Windsock.color(:brand, 500).to_hex
    assert_equal "120rem", Windsock[:breakpoint, "3xl"]
    assert_same Windsock.theme, Windsock.theme
    assert_kind_of Windsock::Color, Windsock.colors["brand-500"]
    assert_includes Windsock.scale_names, "brand"
    assert_equal Windsock.theme.scale(:brand), Windsock.scale(:brand)
    assert_equal Windsock.scale_names, Windsock.scales.keys
  end

  def test_reset_reloads
    before = Windsock.theme
    Windsock.reset!
    refute_same before, Windsock.theme
  end

  def test_requires_path
    Windsock.path = nil
    Windsock.reset!
    assert_raises(Windsock::Error) { Windsock.theme }
  end

  def test_helper_formats
    assert_equal "#2b7fff", tailwind_color(:brand, 500)
    assert_equal "rgb(43 127 255)", tailwind_color(:brand, 500, format: :rgb)
    assert_equal "rgba(43, 127, 255, 1)", tailwind_color("brand-500", format: :rgba)
    assert_equal "oklch(62.3% 0.214 259.815)", tailwind_color(:brand, 500, format: :css)
    assert_equal "120rem", tailwind_value(:breakpoint, "3xl")
    assert_raises(Windsock::NotFound) { tailwind_color(:nope) }
    assert_raises(ArgumentError) { tailwind_color(:brand, 500, format: :hsl) }
    assert_equal "#ffffff", tailwind_text_color(:brand, 900)
    assert_equal "rgb(0 0 0)", tailwind_text_color(:brand, 50, format: :rgb)
    assert_equal Windsock.scale(:brand), tailwind_scale(:brand)
    error = assert_raises(ArgumentError) { tailwind_color(:brand) }
    assert_match(/"brand" is a color scale; pick a step: 50, 500, 900, muted/, error.message)
    assert_raises(ArgumentError) { tailwind_text_color(:brand) }
  end
end
