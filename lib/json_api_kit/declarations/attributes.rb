# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Attributes
      def initialize(attributes, schema:)
        @attributes = attributes
        @schema = schema
      end

      def values_for(record) = attributes.to_h { [it.name, it.value_for(record)] }

      def columns = Columns.for(attributes.map { it.column_for(schema) })

      private

      attr_reader :attributes, :schema
    end
  end
end
