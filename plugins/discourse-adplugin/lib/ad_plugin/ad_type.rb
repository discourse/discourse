# frozen_string_literal: true

module AdPlugin
  class AdType
    def self.types
      @types ||= Enum.new(:house, :adsense, :dfp, :amazon, :carbon, :adbutler, start: 0)
    end

    def self.[](type)
      types[type]
    end

    def self.valid?(type)
      types.values.include?(type)
    end

    def self.enum_hash
      @enum_hash ||= types.to_h.freeze
    end
  end
end
