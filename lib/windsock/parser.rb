# frozen_string_literal: true

module Windsock
  # Extracts theme variables from Tailwind v4 CSS.
  #
  # Walks the stylesheet looking for top-level `@theme { ... }` blocks and
  # `@import` statements. Everything else (`@layer`, `@utility`, plain rules)
  # is skipped. `@import "tailwindcss"` pulls in the bundled default theme.
  #
  # Precedence follows Tailwind: values from `@theme default` blocks never
  # override values set in a regular `@theme` block, regardless of order.
  # `--color-*: initial` clears a namespace; `--*: initial` clears everything.
  class Parser
    TAILWIND_IMPORTS = %w[tailwindcss tailwindcss/theme tailwindcss/theme.css].freeze

    attr_reader :vars, :files

    def self.parse(css, base_dir: nil)
      new.parse(css, base_dir: base_dir)
    end

    def self.parse_file(path)
      new.parse_file(path)
    end

    def initialize
      @vars = {}
      @owned = {} # keys set by a non-default @theme block
      @files = []
    end

    def parse_file(path)
      path = File.expand_path(path)
      return self if files.include?(path)

      files << path
      parse(File.read(path), base_dir: File.dirname(path))
    end

    def parse(css, base_dir: nil)
      Scanner.new(strip_comments(css)).each_rule do |name, prelude, body|
        case name
        when "import" then import(prelude, base_dir)
        when "theme" then theme_block(prelude, body)
        end
      end
      self
    end

    private

    def strip_comments(css)
      css.gsub(%r{/\*.*?\*/}m, "")
    end

    def import(prelude, base_dir)
      spec = prelude[/\A\s*(?:url\()?\s*["']([^"']+)["']/, 1]
      return unless spec

      if TAILWIND_IMPORTS.include?(spec)
        parse_file(Windsock.default_theme_path)
      elsif spec.start_with?("./", "../", "/")
        parse_file(resolve_import(spec, base_dir))
      end
      # Bare specifiers ("tailwindcss/utilities", "tw-animate-css", ...) are ignored.
    end

    def resolve_import(spec, base_dir)
      base = spec.start_with?("/") ? spec : File.expand_path(spec, base_dir || Dir.pwd)
      candidates = [base, "#{base}.css", File.join(base, "index.css")]
      candidates.find { |path| File.file?(path) } ||
        raise(ImportError, "cannot resolve @import #{spec.inspect} from #{base_dir || Dir.pwd}")
    end

    def theme_block(prelude, body)
      default = prelude.split.include?("default")
      Scanner.new(body).each_declaration do |name, value|
        next unless name.start_with?("--")

        key = name[2..]
        value = value.gsub(/\s*\n\s*/, " ")
        if value == "initial"
          reset(key)
        else
          assign(key, value, default)
        end
      end
    end

    def assign(key, value, default)
      return if default && @owned[key]

      @vars[key] = value
      @owned[key] = true unless default
    end

    def reset(key)
      if key == "*"
        @vars.clear
        @owned.clear
      elsif key.end_with?("-*")
        prefix = key[0..-2]
        @vars.delete_if { |k, _| k.start_with?(prefix) }
        @owned.delete_if { |k, _| k.start_with?(prefix) }
      else
        @vars.delete(key)
        @owned.delete(key)
      end
    end

    # Minimal CSS tokenizer: finds at-rules and declarations at one nesting
    # level, honouring strings, parentheses and braces.
    class Scanner
      def initialize(css)
        @css = css
        @pos = 0
      end

      # Yields [name, prelude, body] for each at-rule. Body is nil for
      # statement at-rules (`@import ...;`). Other rules are skipped.
      def each_rule
        until eof?
          skip_whitespace
          break if eof?

          if peek == "@"
            yield(*read_at_rule)
          else
            skip_rule
          end
        end
      end

      # Yields [name, value] for each declaration. Nested blocks (e.g.
      # `@keyframes` inside `@theme`) are skipped.
      def each_declaration
        until eof?
          skip_whitespace
          break if eof?

          if peek == "@"
            read_at_rule
          elsif peek == ";"
            advance
          else
            text = read_until(";", "{", "}")
            if peek == "{"
              skip_block
            else
              advance if peek == ";"
              name, value = text.split(":", 2)
              yield(name.strip, value.strip) if value
            end
          end
        end
      end

      private

      def eof? = @pos >= @css.length
      def peek = @css[@pos]
      def advance = (@pos += 1)

      def skip_whitespace
        @pos += 1 while !eof? && peek.match?(/\s/)
      end

      def read_at_rule
        advance # "@"
        name = @css[@pos..][/\A[\w-]+/] || ""
        @pos += name.length
        prelude = read_until(";", "{", "}").strip

        case peek
        when "{"
          [name, prelude, read_block]
        else
          advance if peek == ";"
          [name, prelude, nil]
        end
      end

      def skip_rule
        read_until(";", "{")
        peek == "{" ? skip_block : advance
      end

      def skip_block
        read_block
      end

      # Assumes peek == "{". Returns the inner text and moves past "}".
      def read_block
        advance
        start = @pos
        depth = 1
        until eof?
          char = peek
          if %w[" '].include?(char)
            skip_string
            next
          end
          depth += 1 if char == "{"
          depth -= 1 if char == "}"
          advance
          return @css[start...(@pos - 1)] if depth.zero?
        end
        @css[start..]
      end

      # Reads until one of the stop chars at paren depth zero, outside strings.
      def read_until(*stops)
        start = @pos
        depth = 0
        until eof?
          char = peek
          if %w[" '].include?(char)
            skip_string
            next
          end
          depth += 1 if char == "("
          depth -= 1 if char == ")" && depth.positive?
          break if depth.zero? && stops.include?(char)

          advance
        end
        @css[start...@pos]
      end

      def skip_string
        quote = peek
        advance
        until eof?
          char = peek
          advance
          if char == "\\"
            advance
          elsif char == quote
            break
          end
        end
      end
    end
  end
end
