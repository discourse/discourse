# frozen_string_literal: true

module Service
  module Base
    # @!visibility private
    class RawParams
      delegate :slice, :merge, to: :to_h

      def initialize(params)
        @params = params.each_pair.to_h { |key, value| [key.to_sym, value] }.freeze
        freeze
      end

      def to_h
        @params
      end
      alias to_hash to_h

      def method_missing(name, *)
        @params[name]
      end

      def respond_to_missing?(name, include_private = false)
        @params.key?(name) || super
      end
    end
  end
end
