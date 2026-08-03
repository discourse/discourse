# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Sort
      SEPARATOR = "."

      def self.for(name, ...)
        return Related.new(name, ...) if name.to_s.include?(SEPARATOR)
        new(name, ...)
      end

      attr_reader :name

      def initialize(name, column: nil, sql: nil, joins: [], nulls: nil)
        @name = name.to_s
        @column = column
        @sql = sql
        @joins = joins
        @nulls = nulls
      end

      def key(schema:, direction:)
        Pagination::Keyset::Key.new(
          attribute,
          model: schema.model,
          direction:,
          sql: sql_for(schema),
          joins:,
          nulls: placement(schema),
        )
      end

      private

      attr_reader :column, :sql, :joins, :nulls

      def attribute = (column || name.tr(SEPARATOR, "_")).to_sym

      def sql_for(_schema) = sql

      def placement(schema)
        return nulls if nulls
        :last if schema.nullable?(attribute)
      end
    end
  end
end
