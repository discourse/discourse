# frozen_string_literal: true

module Migrations
  module Enum
    def self.extended(base)
      base.instance_variable_set(:@map, {})
    end

    def define_values(*args)
      map =
        if args.size == 1 && args[0].is_a?(Hash)
          args[0]
        else
          args.each_with_object({}) { |sym, h| h[sym] = sym }
        end

      @map = map.freeze

      map.each { |key, val| define_method(key) { val } }
    end

    def keys
      @map.keys
    end

    def values
      @map.values
    end

    def valid?(value)
      @map.value?(value)
    end

    def key_for(value)
      @map.key(value)
    end

    def value_for(key)
      @map.fetch(key) { raise KeyError, "Invalid key: #{key.inspect}" }
    end
  end
end
