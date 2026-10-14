# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "windsock"

require "minitest/autorun"

module Minitest
  class Test
    def fixture_dir
      File.expand_path("fixtures", __dir__)
    end

    def fixture(name)
      File.join(fixture_dir, name)
    end
  end
end
