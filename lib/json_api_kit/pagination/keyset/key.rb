# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Keyset
      # One term of a keyset order: what to order by, which way, and — when the value is
      # not a column of the table — the SQL that produces it and the joins that SQL
      # needs. A key answers for its own value on both sides of the comparison: the one
      # read off a record to mint a cursor, and the one the database sorts on.
      #
      # It holds the model it orders, the way an Arel attribute holds its relation.
      class Key
        DIRECTIONS = %i[asc desc].freeze

        attr_reader :name, :model, :direction, :sql, :joins

        delegate :connection, :table_name, :type_for_attribute, to: :model, private: true
        delegate :quote_table_name, :quote_column_name, to: :connection, private: true

        def initialize(name, model:, direction: :asc, sql: nil, joins: [], nulls_last: false)
          raise ArgumentError, "unknown direction: #{direction}" if !DIRECTIONS.include?(direction)

          @name = name.to_sym
          @model = model
          @direction = direction
          @sql = sql
          @joins = joins
          @nulls_last = nulls_last
        end

        def nulls_last? = @nulls_last

        # A key the table cannot hand over as a column has to be selected under its name
        # before anything can order, compare or read it.
        def projected? = !sql.nil?

        def reverse
          self.class.new(name, model:, direction: opposite, sql:, joins:, nulls_last: nulls_last?)
        end

        # The order terms this key contributes. A nullable key hands its nulls to a flag
        # in front of it and stops asking for one, so expanding an expanded key changes
        # nothing.
        def expand
          return [self] if !nulls_last?
          [NullFlag.new(self), self.class.new(name, model:, direction:, sql:, joins:)]
        end

        def value_for(record) = record.public_send(name)

        # The column the key is read from once the keyset has been projected: its own
        # name, never the SQL behind it, which the wrapping relation no longer exposes.
        def identifier = "#{quoted_table}.#{quoted_name}"

        def value_sql = sql || identifier

        # A cursor carries JSON scalars; the column's own type turns one back into the
        # value it was minted from. A projected key has no column type of its own, and
        # its value passes straight through.
        def cast(value) = type_for_attribute(name).cast(value)

        def select_expression
          return if !projected?
          "#{value_sql} AS #{quoted_name}"
        end

        private

        def opposite = direction == :asc ? :desc : :asc

        def quoted_table = quote_table_name(table_name)

        def quoted_name = quote_column_name(name)
      end
    end
  end
end
