# frozen_string_literal: true

module JsonApiKit
  class Resource
    class IdentifierType < ActiveModel::Type::Value
      def initialize(key_type)
        super()
        @key_type = key_type
      end

      def cast_value(value)
        key_type.cast(value).then { it if it.to_s.casecmp?(value.to_s) }
      end

      private

      attr_reader :key_type
    end
  end
end
