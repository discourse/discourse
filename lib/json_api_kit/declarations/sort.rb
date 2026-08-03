# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Sort
      attr_reader :name

      def initialize(name, column: nil, sql: nil, joins: [], nulls: nil)
        @name = name.to_s
        @column = column
        @sql = sql
        @joins = Array(joins)
        @nulls = nulls
      end

      def key(schema:, direction:)
        Pagination::Keyset::Key.new(
          attribute,
          model: schema.model,
          direction:,
          sql:,
          joins:,
          nulls: placement(schema),
        )
      end

      private

      attr_reader :column, :sql, :joins, :nulls

      def attribute = (column || name.tr(".", "_")).to_sym

      def placement(schema)
        return nulls if nulls
        :last if schema.nullable?(attribute)
      end
    end
  end
end
