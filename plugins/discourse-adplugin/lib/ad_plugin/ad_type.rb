# frozen_string_literal: true

module AdPlugin
  class AdType
    class << self
      def types
        @types ||= Enum.new(:house, :adsense, :dfp, :amazon, :carbon, :adbutler, start: 0)
      end

      def [](type)
        types[type]
      end

      def valid?(type)
        types.values.include?(type)
      end

      def enum_hash
        @enum_hash ||= types.to_h.freeze
      end
    end
  end
end
