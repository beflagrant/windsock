# frozen_string_literal: true

module Windsock
  # A resolved Tailwind theme. Keys are variable names without the leading
  # `--`, e.g. "color-brand-500". Values returned by #[] have `var()` and
  # `--theme()` references expanded; #raw returns the CSS as written.
  class Theme
    NAMESPACES = {
      fonts: "font",
      breakpoints: "breakpoint",
      containers: "container",
      radii: "radius",
      shadows: "shadow",
      inset_shadows: "inset-shadow",
      drop_shadows: "drop-shadow",
      text_sizes: "text",
      tracking: "tracking",
      leading: "leading",
      blurs: "blur",
      easings: "ease",
      animations: "animate",
      aspects: "aspect",
      perspectives: "perspective"
    }.freeze

    REFERENCE = /(?:var|--theme|theme)\(/

    def self.parse(css, base_dir: nil)
      new(Parser.parse(css, base_dir: base_dir).vars)
    end

    def self.from_file(path)
      parser = Parser.parse_file(path)
      new(parser.vars, files: parser.files)
    end

    attr_reader :files

    def initialize(vars, files: [])
      @vars = vars.to_h.transform_keys(&:to_s).freeze
      @files = files
      @resolved = {}
    end

    def key?(*parts)
      @vars.key?(key_for(parts))
    end

    def keys
      @vars.keys
    end

    # Resolved value, or nil. Accepts a full key ("color-brand-500") or
    # parts (:color, :brand, 500).
    def [](*parts)
      key = key_for(parts)
      return nil unless @vars.key?(key)

      @resolved[key] ||= resolve(@vars[key])
    end

    def fetch(*parts)
      self[*parts] || raise(NotFound, "theme has no #{key_for(parts).inspect}")
    end

    def raw(*parts)
      @vars[key_for(parts)]
    end

    # All resolved values under a namespace, keyed by the remainder:
    # namespace(:breakpoint) => { "sm" => "40rem", ... }
    def namespace(name)
      prefix = "#{name}-"
      @vars.keys.grep(/\A#{Regexp.escape(prefix)}/).to_h do |key|
        [key.delete_prefix(prefix), self[key]]
      end
    end

    NAMESPACES.each do |method, ns|
      define_method(method) { namespace(ns) }
    end

    # color(:brand, 500) / color("brand-500") => Color, or nil when missing.
    #
    # color(:brand) with no --color-brand but a brand-50..950 family returns
    # the whole Scale instead of nil: asking for a family is what a human
    # means by it. An exact --color-brand always wins over the scale.
    def color(*parts)
      value = self[:color, *parts]
      return Color.parse(value) if value

      name = key_for(parts)
      scale(name) if scale_names.include?(name)
    end

    def color!(*parts)
      color(*parts) || raise(NotFound, "theme has no color #{key_for([:color, *parts]).inspect}")
    end

    # The theme's own white and black (--color-white / --color-black), which
    # an app may soften (#f5f5f5). Contrast checks measure against these,
    # not pure #fff / #000, so the numbers match what the page shows.
    def white
      single_color(:white) || Color::WHITE
    end

    def black
      single_color(:black) || Color::BLACK
    end

    # The theme's white or black, whichever reads better on the given color:
    # text_color(:brand, 500) => Color.
    def text_color(*parts)
      color = color!(*parts)
      raise NotFound, "#{key_for(parts).inspect} is a scale, not a color" unless color.is_a?(Color)

      color.text_color(white: white, black: black)
    end

    # All colors as { "brand-500" => Color }. Values that aren't colors
    # (currentColor, var() chains that don't resolve) are omitted.
    def colors
      @colors ||= namespace(:color).filter_map do |name, value|
        color = Color.parse(value)
        [name, color] if color
      end.to_h.freeze
    end

    # A single color scale: scale(:brand) => Scale of 50 => Color, ..., 950 => Color.
    # Numeric steps become Integer keys; anything else stays a String.
    def scale(name)
      prefix = "#{name}-"
      steps = colors.select { |k, _| k.start_with?(prefix) }.transform_keys { |k| k.delete_prefix(prefix) }
      Scale.new(name, steps, theme: self)
    end

    # Names you can hand to #scale: ["red", "orange", ..., "brand"]. A color
    # belongs to a scale when its name ends in a numeric step (brand-500);
    # brand-muted rides along with brand.
    def scale_names
      @scale_names ||= colors.keys.filter_map { |k| k[/\A(.+)-\d+\z/, 1] }.uniq.freeze
    end

    # Every scale in the theme, keyed by name: { "red" => Scale, "brand" => Scale, ... }.
    def scales
      scale_names.to_h { |name| [name, scale(name)] }
    end

    # Tailwind's spacing scale: spacing(4) => "1rem" (given --spacing: 0.25rem).
    # Named entries (--spacing-gutter) are looked up directly.
    def spacing(step = nil)
      return self[:spacing] if step.nil?
      return self[:spacing, step] if key?(:spacing, step)

      base = self[:spacing] or return nil
      match = base.match(/\A(-?\d*\.?\d+)([a-z%]*)\z/) or return nil
      "#{trim(match[1].to_f * step.to_f)}#{match[2]}"
    end

    def to_h
      @vars.keys.to_h { |key| [key, self[key]] }
    end

    def inspect
      "#<Windsock::Theme #{@vars.size} vars>"
    end

    private

    # One color by exact key, never a scale.
    def single_color(name)
      value = self[:color, name]
      value && Color.parse(value)
    end

    def key_for(parts)
      parts.flatten.join("-")
    end

    def trim(number)
      number == number.round ? number.round.to_s : number.round(4).to_s
    end

    # Expands var(--x), var(--x, fallback) and --theme(--x, fallback).
    def resolve(value, depth = 0)
      return value if depth > 20 || !value.match?(REFERENCE)

      out = +""
      rest = value
      while (match = REFERENCE.match(rest))
        out << match.pre_match
        inner, rest = balanced(match.post_match)
        name, fallback = inner.split(",", 2)
        out << lookup(name.strip.delete_prefix("--"), fallback&.strip, depth)
      end
      out << rest
    end

    def lookup(name, fallback, depth)
      if @vars.key?(name)
        resolve(@vars[name], depth + 1)
      elsif fallback && fallback != "initial"
        resolve(fallback, depth + 1)
      else
        "var(--#{name})"
      end
    end

    # Given text starting just after "(", returns [inside, after_closing_paren].
    def balanced(text)
      depth = 1
      text.each_char.with_index do |char, i|
        depth += 1 if char == "("
        depth -= 1 if char == ")"
        return [text[0...i], text[(i + 1)..]] if depth.zero?
      end
      [text, ""]
    end
  end
end
