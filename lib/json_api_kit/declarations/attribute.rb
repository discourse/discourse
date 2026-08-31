# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Attribute
      attr_reader :name

      def initialize(name, &value)
        @name = name.to_s
        @value = value
      end

      def value_for(record)
        return value.call(record) if value
        record.public_send(name)
      end

      def column_for(schema)
        return if value
        schema.column(name)
      end

      private

      attr_reader :value
    end
  end
end
