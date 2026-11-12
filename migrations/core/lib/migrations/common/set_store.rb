# frozen_string_literal: true
module Migrations
  module SetStore
    def self.create(depth)
      case depth
      when 0
        SimpleSet.new
      when 1
        KeyValueSet.new
      when 2
        TwoKeySet.new
      when 3
        ThreeKeySet.new
      else
        raise ArgumentError, "Unsupported nesting depth: #{depth}"
      end
    end
  end
end
