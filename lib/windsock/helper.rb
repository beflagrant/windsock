# frozen_string_literal: true

module Windsock
  # View and mailer helpers. Included into ActionView by the Railtie; can be
  # mixed into anything else by hand.
  module Helper
    FORMATS = %i[hex rgb rgba css].freeze

    def tailwind_theme
      Windsock.theme
    end

    # tailwind_color(:brand, 500)               => "#3b82f6"
    # tailwind_color(:brand, 500, format: :rgb) => "rgb(59 130 246)"
    # tailwind_color("brand-500", format: :css) => "oklch(62.3% 0.214 259.815)"
    def tailwind_color(*parts, format: :hex)
      tailwind_format(tailwind_single_color(*parts), format)
    end

    # Black or white, whichever reads better on the given theme color:
    #   <a style="background: <%= tailwind_color(:brand, 500) %>; color: <%= tailwind_text_color(:brand, 500) %>">
    def tailwind_text_color(*parts, format: :hex)
      theme = Windsock.theme
      tailwind_format(tailwind_single_color(*parts).text_color(white: theme.white, black: theme.black), format)
    end

    def tailwind_scale(name)
      Windsock.theme.scale(name)
    end

    def tailwind_value(*parts)
      Windsock.theme.fetch(*parts)
    end

    private

    # A view wants one color, never a family. color! may hand back a Scale
    # for tailwind_color(:brand); say so instead of failing on to_hex.
    def tailwind_single_color(*parts)
      color = Windsock.theme.color!(*parts)
      return color if color.is_a?(Color)

      raise ArgumentError, "#{color.name.inspect} is a color scale; pick a step: #{color.steps.join(", ")}"
    end

    def tailwind_format(color, format)
      case format
      when :hex then color.to_hex
      when :rgb then color.to_rgb
      when :rgba then color.to_rgba
      when :css then color.source
      else raise ArgumentError, "format must be one of #{FORMATS.join(", ")}"
      end
    end
  end
end
