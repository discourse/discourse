# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Attributes
      def initialize(attributes, guardian:, schema:)
        @attributes = attributes
        @guardian = guardian
        @schema = schema
      end

      def values_for(record) = readable(record).to_h { [it.name, it.value_for(record)] }

      def columns = Columns.for(attributes.map { it.column_for(schema) })

      private

      attr_reader :attributes, :guardian, :schema

      def readable(record) = attributes.select { it.readable_for?(guardian, record) }
    end
  end
end
