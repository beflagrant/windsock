# frozen_string_literal: true

require_relative "windsock/version"
require_relative "windsock/color"
require_relative "windsock/parser"
require_relative "windsock/scale"
require_relative "windsock/theme"
require_relative "windsock/helper"

# Read your Tailwind v4 theme from Ruby.
#
#   Windsock.path = "app/assets/tailwind/application.css"
#   Windsock.color(:brand, 500).to_hex   # => "#3b82f6"
#   Windsock.scale(:brand)               # => 50..950 with WCAG contrast
#   Windsock.theme.breakpoints           # => { "sm" => "40rem", ... }
module Windsock
  class Error < StandardError; end
  class ParseError < Error; end
  class ImportError < Error; end
  class NotFound < Error; end

  TAILWIND_VERSION = "4.3.3"

  class << self
    # Path to the app's main Tailwind stylesheet. Set by the Railtie in Rails.
    attr_accessor :path

    def theme
      @theme ||= load(path || raise(Error, "Windsock.path is not set"))
    end

    def reset!
      @theme = nil
    end

    def load(path)
      Theme.from_file(path)
    end

    def parse(css, base_dir: nil)
      Theme.parse(css, base_dir: base_dir)
    end

    # Tailwind's built-in palette and scales, without any app customisation.
    def default_theme
      @default_theme ||= Theme.from_file(default_theme_path)
    end

    def default_theme_path
      File.expand_path("windsock/tailwind/theme.css", __dir__)
    end

    def color(...) = theme.color(...)
    def color!(...) = theme.color!(...)
    def colors = theme.colors
    def scale(...) = theme.scale(...)
    def scales = theme.scales
    def scale_names = theme.scale_names
    def fetch(...) = theme.fetch(...)

    def [](*parts)
      theme[*parts]
    end
  end
end

require_relative "windsock/railtie" if defined?(Rails::Railtie)
