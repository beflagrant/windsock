# frozen_string_literal: true

require "pp"

module Windsock
  # One color scale from the theme: scale(:brand) => 50..950 steps.
  #
  # Behaves like a Hash of step => Color (Enumerable over [step, color]
  # pairs) and adds WCAG contrast lookups so you can pick a usable step
  # without leaving the console.
  #
  #   scale = Windsock.scale(:brand)
  #   scale[500].to_hex                       # "#2b7fff"
  #   scale.contrast(:white)                  # { 50 => 1.05, ..., 950 => 17.3 }
  #   scale.accessible(on: :white).steps      # steps that pass AA for text
  #   scale.text_colors[500].to_hex           # "#ffffff" — text to put on brand-500
  #
  # "white" and "black" mean the theme's --color-white / --color-black when
  # the scale came from a theme (an app may soften white to #f5f5f5), and
  # pure #fff / #000 otherwise. Any other name is looked up in the theme
  # first (scale.contrast(:surface)), then parsed as CSS.
  class Scale
    include Enumerable

    attr_reader :name

    def initialize(name, steps, theme: nil)
      @name = name.to_s
      @theme = theme
      @steps = steps.to_h { |step, color| [normalize(step), Color.parse!(color)] }.freeze
    end

    def white
      @theme&.white || Color::WHITE
    end

    def black
      @theme&.black || Color::BLACK
    end

    # scale[500], scale["500"], scale[:muted] all work.
    def [](step)
      @steps[normalize(step)]
    end

    def fetch(step)
      self[step] || raise(NotFound, "scale #{name.inspect} has no step #{step.inspect}")
    end

    def step?(step)
      @steps.key?(normalize(step))
    end
    alias key? step?

    def steps
      @steps.keys
    end
    alias keys steps

    def colors
      @steps.values
    end
    alias values colors

    def each(&)
      return enum_for(:each) unless block_given?

      @steps.each(&)
    end

    def size
      @steps.size
    end
    alias length size

    def empty?
      @steps.empty?
    end

    def to_h
      @steps.dup
    end

    # WCAG contrast ratio of every step against +on+ (a Color, a theme color
    # name, or any CSS color): { 50 => 1.05, 100 => 1.12, ... }.
    def contrast(on = :white)
      other = resolve(on)
      @steps.transform_values { |color| color.contrast(other).round(2) }
    end

    # The steps whose contrast against +on+ meets a WCAG level, as a new
    # Scale. Levels: :aa (4.5), :aa_large (3), :aaa (7), :aaa_large (4.5).
    #
    #   scale.accessible(on: :white)               # text colors usable on white
    #   scale.accessible(on: :black, level: :aaa)
    def accessible(on: :white, level: :aa)
      other = resolve(on)
      Scale.new(name, @steps.select { |_, color| color.accessible?(other, level: level) }, theme: @theme)
    end

    # The theme's black or white, per step, for text placed on that step:
    # { 50 => #000000, ..., 900 => #ffffff }.
    def text_colors
      @steps.transform_values { |color| color.text_color(white: white, black: black) }
    end

    def ==(other)
      other.is_a?(Scale) && name == other.name && to_h == other.to_h
    end
    alias eql? ==

    def hash
      [name, @steps].hash
    end

    def to_s
      "#{name}: " + @steps.map { |step, color| "#{step}=#{color.to_hex}" }.join(" ")
    end

    # A table, one row per step: contrast against white and black, and the
    # text color to use on the step. Ratios that meet +level+ (default AA,
    # 4.5:1) print green, the rest red, when +color+ is on. +color+ defaults
    # to whether stdout is a terminal, so logs and tests stay plain.
    #
    #   scale.table                      # what the console shows
    #   scale.table(level: :aaa)
    #   puts scale.table(color: false)
    def table(level: DEFAULT_LEVEL, color: $stdout.tty?)
      return "#<Windsock::Scale #{name} (empty)>" if empty?

      minimum = Color::WCAG.fetch(level) { raise ArgumentError, "level must be one of #{Color::WCAG.keys.join(", ")}" }
      width = steps.map { |s| s.to_s.length }.max
      rows = @steps.map do |step, c|
        format("  %#{width}s  %-9s  %s  %s  %s", step, c.to_hex,
               ratio_cell(c.contrast(white), minimum, color),
               ratio_cell(c.contrast(black), minimum, color),
               c.text_color(white: white, black: black) == white ? "white" : "black")
      end
      header = format("  %#{width}s  %-9s  %6s  %6s  %s", "step", "hex", "white", "black", "text")
      title = "#<Windsock::Scale #{name} (#{size} steps; contrast vs white #{white.to_hex} / black #{black.to_hex}; " \
              "#{level.to_s.upcase.tr("_", " ")} needs #{minimum}:1; text = what to write on it)"
      [title, header, *rows, ">"].join("\n")
    end

    def inspect
      table
    end

    # IRB's pretty printer wraps anything that inspects as #<...> in green and
    # re-lexes the rest as Ruby, so the first red cell ended its green and
    # the rows after it came out half-coloured. Hand it the finished table
    # through the base PrettyPrint#text so nothing is re-coloured.
    def pretty_print(q)
      PrettyPrint.instance_method(:text).bind_call(q, table)
    end

    DEFAULT_LEVEL = :aa
    GREEN = "\e[32m"
    RED = "\e[31m"
    RESET = "\e[0m"

    private

    # :white / :black => the theme's; another theme color name => that;
    # a Color => itself; anything else => parsed as CSS.
    def resolve(on)
      return on if on.is_a?(Color)

      key = on.to_s
      return white if key == "white"
      return black if key == "black"

      themed = @theme && @theme[:color, key]
      Color.parse!(themed || key)
    end

    def ratio_cell(ratio, minimum, color)
      cell = format("%6.2f", ratio)
      return cell unless color

      "#{ratio >= minimum ? GREEN : RED}#{cell}#{RESET}"
    end

    def normalize(step)
      text = step.to_s
      text.match?(/\A\d+\z/) ? text.to_i : text
    end
  end
end
