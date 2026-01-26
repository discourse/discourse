# frozen_string_literal: true

require "digest/xxhash"

module Migrations
  module ID
    def self.hash(value)
      Digest::XXH3_128bits.base64digest(value)
    end

    def self.build(part1, part2, *others)
      [part1, part2, *others].join("-")
    end
  end
end
