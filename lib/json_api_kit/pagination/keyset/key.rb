# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Keyset
      class Key
        attr_reader :name, :model, :direction, :sql, :joins

        delegate :connection, :table_name, :type_for_attribute, to: :model, private: true
        delegate :quote_table_name, :quote_column_name, to: :connection, private: true
        delegate :operator, to: :direction
        delegate :trailing?, :read_first?, to: :nulls, prefix: true

        def initialize(name, model:, direction: :asc, sql: nil, joins: [], nulls: nil)
          @name = name.to_sym
          @model = model
          @direction = Direction.for(direction)
          @sql = sql
          @joins = joins
          @nulls = Nulls.for(nulls, direction: @direction)
        end

        def nullable? = nulls.expected?

        def projected? = sql.present?

        def reverse = with(direction: direction.other_way, nulls: nulls.other_end)

        def without_nulls = with(nulls: nil)

        def ordering
          Arel.sql("#{identifier} #{direction.to_sql}#{nulls.to_sql}")
        end

        def valued_condition = ->(scope) { scope.where("#{value_sql} IS NOT NULL") }

        def null_condition = ->(scope) { scope.where("#{value_sql} IS NULL") }

        def value_for(record) = record.public_send(name)

        def named?(other) = name.to_s == other.to_s

        def to_s = name.to_s

        def identifier = "#{quoted_table}.#{quoted_name}"

        def value_sql = sql || identifier

        def at_or_after(scope, value) = scope.where("#{value_sql} #{operator}= ?", cast(value))

        def cast(value) = type_for_attribute(name).cast(value)

        def select_expression
          return unless projected?
          "#{value_sql} AS #{quoted_name}"
        end

        private

        attr_reader :nulls

        def with(**changes)
          self.class.new(
            name,
            model:,
            direction: direction.to_sym,
            sql:,
            joins:,
            nulls: nulls.placement,
            **changes,
          )
        end

        def quoted_table = quote_table_name(table_name)

        def quoted_name = quote_column_name(name)
      end
    end
  end
end
