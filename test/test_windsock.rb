# frozen_string_literal: true

require "test_helper"

class TestWindsock < Minitest::Test
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
end
