# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Keyset
      # One term of a keyset order: what to order by, which way, and — when the value
      # is not a column of the table — the SQL that produces it and the joins that SQL
      # needs. A key answers for its own value on both sides of the comparison: the
      # one read off a record to mint a cursor, and the one the database sorts on.
      class Key
        DIRECTIONS = %i[asc desc].freeze

        attr_reader :name, :direction, :sql, :joins

        def initialize(name, direction: :asc, sql: nil, joins: [], nulls_last: false)
          if !DIRECTIONS.include?(direction)
            raise ArgumentError, "#{direction.inspect} is not a sort direction"
          end

          @name = name.to_sym
          @direction = direction
          @sql = sql
          @joins = joins
          @nulls_last = nulls_last
        end

        def nulls_last? = @nulls_last

        # A key the table cannot hand over as a column has to be selected under its
        # name before anything can order, compare or read it.
        def projected? = !sql.nil?

        def reverse
          self.class.new(name, direction: opposite, sql:, joins:, nulls_last: nulls_last?)
        end

        # The order terms this key contributes. A nullable key hands its nulls to a flag
        # in front of it and stops asking for one, so expanding an expanded key changes
        # nothing.
        def expand
          return [self] if !nulls_last?
          [NullFlag.new(self), self.class.new(name, direction:, sql:, joins:)]
        end

        def value_for(record) = record.public_send(name)

        def value_sql(model)
          sql || "#{model.connection.quote_table_name(model.table_name)}.#{quoted_name(model)}"
        end

        def select_expression(model)
          return if !projected?
          "#{value_sql(model)} AS #{quoted_name(model)}"
        end

        private

        def opposite = direction == :asc ? :desc : :asc

        def quoted_name(model) = model.connection.quote_column_name(name)
      end
    end
  end
end
