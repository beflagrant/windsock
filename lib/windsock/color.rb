# frozen_string_literal: true

module Windsock
  # A parsed CSS color. Stores gamma-encoded sRGB components as floats in 0..1
  # plus alpha, and remembers the original CSS text.
  #
  # Accepts hex, named colors, rgb()/rgba(), hsl()/hsla(), oklch(), oklab(),
  # color(srgb ...) and Tailwind's --alpha(<color> / <alpha>).
  class Color
    FUNCTION = /\A(--alpha|oklch|oklab|rgba?|hsla?|color)\(\s*(.*)\s*\)\z/mi
    JND = 0.02 # just-noticeable difference in OKLab, per CSS Color 4
    EPSILON = 0.0001

    attr_reader :source, :r, :g, :b, :alpha

    NAMED = {
      "transparent" => [0.0, 0.0, 0.0, 0.0], "aliceblue" => "#f0f8ff", "antiquewhite" => "#faebd7",
      "aqua" => "#00ffff", "aquamarine" => "#7fffd4", "azure" => "#f0ffff", "beige" => "#f5f5dc",
      "bisque" => "#ffe4c4", "black" => "#000000", "blanchedalmond" => "#ffebcd", "blue" => "#0000ff",
      "blueviolet" => "#8a2be2", "brown" => "#a52a2a", "burlywood" => "#deb887", "cadetblue" => "#5f9ea0",
      "chartreuse" => "#7fff00", "chocolate" => "#d2691e", "coral" => "#ff7f50",
      "cornflowerblue" => "#6495ed", "cornsilk" => "#fff8dc", "crimson" => "#dc143c", "cyan" => "#00ffff",
      "darkblue" => "#00008b", "darkcyan" => "#008b8b", "darkgoldenrod" => "#b8860b", "darkgray" => "#a9a9a9",
      "darkgreen" => "#006400", "darkgrey" => "#a9a9a9", "darkkhaki" => "#bdb76b", "darkmagenta" => "#8b008b",
      "darkolivegreen" => "#556b2f", "darkorange" => "#ff8c00", "darkorchid" => "#9932cc",
      "darkred" => "#8b0000", "darksalmon" => "#e9967a", "darkseagreen" => "#8fbc8f",
      "darkslateblue" => "#483d8b", "darkslategray" => "#2f4f4f", "darkslategrey" => "#2f4f4f",
      "darkturquoise" => "#00ced1", "darkviolet" => "#9400d3", "deeppink" => "#ff1493",
      "deepskyblue" => "#00bfff", "dimgray" => "#696969", "dimgrey" => "#696969", "dodgerblue" => "#1e90ff",
      "firebrick" => "#b22222", "floralwhite" => "#fffaf0", "forestgreen" => "#228b22",
      "fuchsia" => "#ff00ff", "gainsboro" => "#dcdcdc", "ghostwhite" => "#f8f8ff", "gold" => "#ffd700",
      "goldenrod" => "#daa520", "gray" => "#808080", "green" => "#008000", "greenyellow" => "#adff2f",
      "grey" => "#808080", "honeydew" => "#f0fff0", "hotpink" => "#ff69b4", "indianred" => "#cd5c5c",
      "indigo" => "#4b0082", "ivory" => "#fffff0", "khaki" => "#f0e68c", "lavender" => "#e6e6fa",
      "lavenderblush" => "#fff0f5", "lawngreen" => "#7cfc00", "lemonchiffon" => "#fffacd",
      "lightblue" => "#add8e6", "lightcoral" => "#f08080", "lightcyan" => "#e0ffff",
      "lightgoldenrodyellow" => "#fafad2", "lightgray" => "#d3d3d3", "lightgreen" => "#90ee90",
      "lightgrey" => "#d3d3d3", "lightpink" => "#ffb6c1", "lightsalmon" => "#ffa07a",
      "lightseagreen" => "#20b2aa", "lightskyblue" => "#87cefa", "lightslategray" => "#778899",
      "lightslategrey" => "#778899", "lightsteelblue" => "#b0c4de", "lightyellow" => "#ffffe0",
      "lime" => "#00ff00", "limegreen" => "#32cd32", "linen" => "#faf0e6", "magenta" => "#ff00ff",
      "maroon" => "#800000", "mediumaquamarine" => "#66cdaa", "mediumblue" => "#0000cd",
      "mediumorchid" => "#ba55d3", "mediumpurple" => "#9370db", "mediumseagreen" => "#3cb371",
      "mediumslateblue" => "#7b68ee", "mediumspringgreen" => "#00fa9a", "mediumturquoise" => "#48d1cc",
      "mediumvioletred" => "#c71585", "midnightblue" => "#191970", "mintcream" => "#f5fffa",
      "mistyrose" => "#ffe4e1", "moccasin" => "#ffe4b5", "navajowhite" => "#ffdead", "navy" => "#000080",
      "oldlace" => "#fdf5e6", "olive" => "#808000", "olivedrab" => "#6b8e23", "orange" => "#ffa500",
      "orangered" => "#ff4500", "orchid" => "#da70d6", "palegoldenrod" => "#eee8aa", "palegreen" => "#98fb98",
      "paleturquoise" => "#afeeee", "palevioletred" => "#db7093", "papayawhip" => "#ffefd5",
      "peachpuff" => "#ffdab9", "peru" => "#cd853f", "pink" => "#ffc0cb", "plum" => "#dda0dd",
      "powderblue" => "#b0e0e6", "purple" => "#800080", "rebeccapurple" => "#663399", "red" => "#ff0000",
      "rosybrown" => "#bc8f8f", "royalblue" => "#4169e1", "saddlebrown" => "#8b4513", "salmon" => "#fa8072",
      "sandybrown" => "#f4a460", "seagreen" => "#2e8b57", "seashell" => "#fff5ee", "sienna" => "#a0522d",
      "silver" => "#c0c0c0", "skyblue" => "#87ceeb", "slateblue" => "#6a5acd", "slategray" => "#708090",
      "slategrey" => "#708090", "snow" => "#fffafa", "springgreen" => "#00ff7f", "steelblue" => "#4682b4",
      "tan" => "#d2b48c", "teal" => "#008080", "thistle" => "#d8bfd8", "tomato" => "#ff6347",
      "turquoise" => "#40e0d0", "violet" => "#ee82ee", "wheat" => "#f5deb3", "white" => "#ffffff",
      "whitesmoke" => "#f5f5f5", "yellow" => "#ffff00", "yellowgreen" => "#9acd32"
    }.freeze

    def self.parse(css)
      return css if css.is_a?(Color)

      text = css.to_s.strip
      return nil if text.empty?

      rgba = parse_components(text)
      rgba && new(*rgba, source: text)
    end

    def self.parse!(css)
      parse(css) || raise(ParseError, "cannot parse color: #{css.inspect}")
    end

    def initialize(r, g, b, alpha = 1.0, source: nil)
      @r = clamp(r)
      @g = clamp(g)
      @b = clamp(b)
      @alpha = clamp(alpha)
      @source = source
    end

    # Integer RGB channels, 0..255.
    def rgb
      [r, g, b].map { |c| (c * 255).round }
    end

    def red   = rgb[0]
    def green = rgb[1]
    def blue  = rgb[2]

    # "#rrggbb", or "#rrggbbaa" when alpha < 1.
    def to_hex(alpha: true)
      channels = rgb
      channels << (self.alpha * 255).round if alpha && !opaque?
      "##{channels.map { |c| c.to_s(16).rjust(2, "0") }.join}"
    end
    alias hex to_hex

    # Modern syntax: "rgb(59 130 246)" or "rgb(59 130 246 / 0.5)".
    def to_rgb
      base = "rgb(#{rgb.join(" ")}"
      opaque? ? "#{base})" : "#{base} / #{fmt(alpha)})"
    end

    # Legacy comma syntax, always with alpha: "rgba(59, 130, 246, 1)".
    # Safest form for email clients that choke on modern color syntax.
    def to_rgba
      "rgba(#{rgb.join(", ")}, #{fmt(alpha)})"
    end

    def opaque?
      alpha >= 1.0
    end

    # WCAG relative luminance, 0 (black) .. 1 (white).
    def luminance
      lr, lg, lb = [r, g, b].map { |c| Color.to_linear(c) }
      (0.2126 * lr) + (0.7152 * lg) + (0.0722 * lb)
    end

    # True when white text reads better on this color than black does.
    def dark?
      luminance < 0.179
    end

    def light?
      !dark?
    end

    # WCAG contrast ratio against another color (a Color or any CSS color).
    def contrast(other)
      a = luminance
      b = Color.parse!(other.to_s).luminance
      a, b = b, a if b > a
      (a + 0.05) / (b + 0.05)
    end

    # Minimum contrast ratios from WCAG 2.x. "Large" text is 18pt+ or 14pt bold.
    WCAG = { aa: 4.5, aa_large: 3.0, aaa: 7.0, aaa_large: 4.5 }.freeze

    # Does text in this color on +other+ (or vice versa) meet a WCAG level?
    #
    #   color.accessible?("#fff")                    # AA, normal text
    #   color.accessible?(:white, level: :aa_large)
    def accessible?(other, level: :aa)
      ratio = WCAG.fetch(level) { raise ArgumentError, "level must be one of #{WCAG.keys.join(", ")}" }
      contrast(other) >= ratio
    end

    def aa?(other, large: false) = accessible?(other, level: large ? :aa_large : :aa)
    def aaa?(other, large: false) = accessible?(other, level: large ? :aaa_large : :aaa)

    # The highest WCAG level this pair reaches for normal text: :aaa, :aa,
    # :aa_large (fine for headings only), or :fail.
    def contrast_level(other)
      ratio = contrast(other)
      if ratio >= WCAG[:aaa] then :aaa
      elsif ratio >= WCAG[:aa] then :aa
      elsif ratio >= WCAG[:aa_large] then :aa_large
      else :fail
      end
    end

    # Black or white, whichever contrasts more with this color. For button
    # labels, badges, anything with text on a theme color. Pass the theme's
    # own white and black when they aren't pure (Theme#text_color does).
    def text_color(white: WHITE, black: BLACK)
      contrast(white) >= contrast(black) ? white : black
    end

    # "white" / "black" for named colors, else the hex.
    def name
      NAMED.key(to_hex) || to_hex
    end

    def to_s
      source || to_hex
    end

    def inspect
      "#<Windsock::Color #{to_hex} (#{source})>"
    end

    def ==(other)
      other.is_a?(Color) && to_hex == other.to_hex
    end
    alias eql? ==

    def hash
      to_hex.hash
    end

    private

    def clamp(value)
      value.to_f.clamp(0.0, 1.0)
    end

    def fmt(number)
      number == number.round ? number.round.to_s : number.round(3).to_s
    end

    class << self
      def to_linear(c)
        c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
      end

      def to_gamma(c)
        c <= 0.0031308 ? 12.92 * c : (1.055 * (c**(1 / 2.4))) - 0.055
      end

      private

      def parse_components(text)
        if text.start_with?("#")
          parse_hex(text)
        elsif (match = FUNCTION.match(text))
          parse_function(match[1].downcase, match[2])
        else
          named = NAMED[text.downcase]
          named.is_a?(String) ? parse_hex(named) : named
        end
      end

      def parse_hex(text)
        digits = text[1..]
        return nil unless digits.match?(/\A\h{3,4}\z|\A\h{6}\z|\A\h{8}\z/)

        digits = digits.chars.map { |c| c * 2 }.join if digits.length <= 4
        channels = digits.scan(/\h\h/).map { |h| h.hex / 255.0 }
        channels << 1.0 if channels.length == 3
        channels
      end

      def parse_function(name, body)
        head, alpha_arg = split_top_level(body, "/")
        alpha = alpha_arg ? parse_alpha(alpha_arg.strip) : 1.0
        return alpha_function(head.strip, alpha) if name == "--alpha"

        args = split_args(head)
        # Legacy rgba(r, g, b, a) / hsla(h, s, l, a).
        alpha = parse_alpha(args.pop) if alpha_arg.nil? && args.length == 4 && %w[rgb rgba hsl hsla].include?(name)

        case name
        when "rgb", "rgba" then rgb_function(args, alpha)
        when "hsl", "hsla" then hsl_function(args, alpha)
        when "oklch" then oklch_function(args, alpha)
        when "oklab" then oklab_function(args, alpha)
        when "color" then color_function(args, alpha)
        end
      end

      # Splits at the first occurrence of +char+ outside parentheses.
      def split_top_level(text, char)
        depth = 0
        text.each_char.with_index do |c, i|
          depth += 1 if c == "("
          depth -= 1 if c == ")"
          return [text[0...i], text[(i + 1)..]] if c == char && depth.zero?
        end
        [text, nil]
      end

      def split_args(text)
        text.strip.split(/\s*,\s*|\s+/).reject(&:empty?)
      end

      def alpha_function(text, alpha)
        inner = parse_components(text)
        inner && (inner[0, 3] + [inner[3] * alpha])
      end

      def rgb_function(args, alpha)
        return nil unless args.length == 3

        args.map { |a| channel(a, 255.0) } << alpha
      end

      def hsl_function(args, alpha)
        return nil unless args.length == 3

        h = hue(args[0]) / 360.0
        s = channel(args[1], 100.0)
        l = channel(args[2], 100.0)
        hsl_to_rgb(h, s, l) << alpha
      end

      def oklch_function(args, alpha)
        return nil unless args.length == 3

        l = lightness(args[0])
        c = args[1].end_with?("%") ? number(args[1]) / 100.0 * 0.4 : number(args[1])
        h = hue(args[2]) * Math::PI / 180
        oklab_to_rgb(l, c * Math.cos(h), c * Math.sin(h)) << alpha
      end

      def oklab_function(args, alpha)
        return nil unless args.length == 3

        a, b = args[1, 2].map { |v| v.end_with?("%") ? number(v) / 100.0 * 0.4 : number(v) }
        oklab_to_rgb(lightness(args[0]), a, b) << alpha
      end

      def color_function(args, alpha)
        return nil unless args.length == 4 && %w[srgb srgb-linear].include?(args[0].downcase)

        channels = args[1, 3].map { |a| channel(a, 1.0) }
        channels = channels.map { |c| to_gamma(c) } if args[0].casecmp?("srgb-linear")
        channels << alpha
      end

      def lightness(value)
        value.end_with?("%") ? number(value) / 100.0 : number(value)
      end

      def channel(value, scale)
        if value == "none"
          0.0
        else
          (value.end_with?("%") ? number(value) / 100.0 : number(value) / scale)
        end
      end

      def parse_alpha(value)
        value.end_with?("%") ? number(value) / 100.0 : number(value)
      end

      def hue(value)
        return 0.0 if value == "none"

        n = number(value)
        case value
        when /rad\z/ then n * 180 / Math::PI
        when /grad\z/ then n * 0.9
        when /turn\z/ then n * 360
        else n
        end
      end

      def number(value)
        Float(value[/-?\d*\.?\d+(?:e[+-]?\d+)?/i] || raise(ParseError, "bad number: #{value.inspect}"))
      end

      def hsl_to_rgb(h, s, l)
        return [l, l, l] if s.zero?

        q = l < 0.5 ? l * (1 + s) : l + s - (l * s)
        p = (2 * l) - q
        [h + (1 / 3.0), h, h - (1 / 3.0)].map { |t| hue_to_rgb(p, q, t) }
      end

      def hue_to_rgb(p, q, t)
        t += 1 if t.negative?
        t -= 1 if t > 1
        return p + ((q - p) * 6 * t) if t < 1 / 6.0
        return q if t < 0.5
        return p + ((q - p) * ((2 / 3.0) - t) * 6) if t < 2 / 3.0

        p
      end

      # OKLab -> gamma-encoded sRGB, gamut mapped per CSS Color 4 §13.2:
      # hold lightness and hue, binary-search chroma, and accept the clipped
      # candidate once it is within a just-noticeable difference (ΔE_OK 0.02)
      # of the unclipped one. Matches what browsers (and Tailwind's docs) show
      # for the saturated v4 palette entries that fall outside sRGB.
      def oklab_to_rgb(l, a, b)
        rgb = oklab_to_linear(l, a, b)
        return rgb.map { |c| to_gamma(c.clamp(0.0, 1.0)) } if in_gamut?(rgb)
        return [l, l, l].map { |c| to_gamma(c.clamp(0.0, 1.0)) } if l <= 0 || l >= 1

        hue = Math.atan2(b, a)
        min = 0.0
        max = Math.sqrt((a * a) + (b * b))
        min_in_gamut = true
        clipped = rgb.map { |c| c.clamp(0.0, 1.0) }

        while max - min > EPSILON
          chroma = (min + max) / 2
          current = oklab_to_linear(l, chroma * Math.cos(hue), chroma * Math.sin(hue))
          if min_in_gamut && in_gamut?(current)
            min = chroma
            next
          end

          clipped = current.map { |c| c.clamp(0.0, 1.0) }
          delta = delta_eok(linear_to_oklab(*clipped), [l, chroma * Math.cos(hue), chroma * Math.sin(hue)])
          if delta < JND
            break if JND - delta < EPSILON

            min_in_gamut = false
            min = chroma
          else
            max = chroma
          end
        end
        clipped.map { |c| to_gamma(c) }
      end

      def in_gamut?(rgb)
        rgb.all? { |c| c.between?(-0.00001, 1.00001) }
      end

      def delta_eok(lab1, lab2)
        Math.sqrt(lab1.zip(lab2).sum { |x, y| (x - y)**2 })
      end

      def linear_to_oklab(r, g, b)
        l = Math.cbrt((0.4122214708 * r) + (0.5363325363 * g) + (0.0514459929 * b))
        m = Math.cbrt((0.2119034982 * r) + (0.6806995451 * g) + (0.1073969566 * b))
        s = Math.cbrt((0.0883024619 * r) + (0.2817188376 * g) + (0.6299787005 * b))
        [
          (0.2104542553 * l) + (0.7936177850 * m) - (0.0040720468 * s),
          (1.9779984951 * l) - (2.4285922050 * m) + (0.4505937099 * s),
          (0.0259040371 * l) + (0.7827717662 * m) - (0.8086757660 * s)
        ]
      end

      # Björn Ottosson's OKLab -> linear sRGB.
      def oklab_to_linear(l, a, b)
        l_ = l + (0.3963377774 * a) + (0.2158037573 * b)
        m_ = l - (0.1055613458 * a) - (0.0638541728 * b)
        s_ = l - (0.0894841775 * a) - (1.2914855480 * b)

        l3 = l_**3
        m3 = m_**3
        s3 = s_**3

        [
          (4.0767416621 * l3) - (3.3077115913 * m3) + (0.2309699292 * s3),
          (-1.2684380046 * l3) + (2.6097574011 * m3) - (0.3413193965 * s3),
          (-0.0041960863 * l3) - (0.7034186147 * m3) + (1.7076147010 * s3)
        ]
      end
    end
  end

  Color::WHITE = Color.parse("#ffffff").freeze
  Color::BLACK = Color.parse("#000000").freeze
end
