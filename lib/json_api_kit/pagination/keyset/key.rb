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
        NULL_PLACEMENTS = %i[first last].freeze

        attr_reader :name, :model, :direction, :sql, :joins, :nulls

        delegate :connection, :table_name, :type_for_attribute, to: :model, private: true
        delegate :quote_table_name, :quote_column_name, to: :connection, private: true

        def initialize(name, model:, direction: :asc, sql: nil, joins: [], nulls: nil)
          raise ArgumentError, "unknown direction: #{direction}" if DIRECTIONS.exclude?(direction)
          raise ArgumentError, "unknown nulls: #{nulls}" if nulls && NULL_PLACEMENTS.exclude?(nulls)

          @name = name.to_sym
          @model = model
          @direction = direction
          @sql = sql
          @joins = joins
          @nulls = nulls
        end

        # A key whose value can be null: the listing is split into segments at it when it
        # leads the order (see Order), and its nulls sort at one named end.
        def nullable? = !nulls.nil?

        # A key the table cannot hand over as a column has to be selected under its name
        # before anything can order, compare or read it.
        def projected? = !sql.nil?

        # Reversing an order sends its nulls to the other end — which is also the only
        # placement a backward scan of an index built for the forward order can serve.
        def reverse
          self.class.new(name, model:, direction: opposite, sql:, joins:, nulls: opposite_nulls)
        end

        # How the database is asked to sort by this key, in the form an index for this order
        # can be scanned in.
        def ordering
          Arel.sql("#{identifier} #{direction.to_s.upcase}#{placement}")
        end

        # Which rows of a scope this key has a value in, and which it does not — the two
        # bands a segmented order is split into when a nullable key leads it.
        def valued_rows = ->(scope) { scope.where("#{value_sql} IS NOT NULL") }

        def null_rows = ->(scope) { scope.where("#{value_sql} IS NULL") }

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
          return unless projected?
          "#{value_sql} AS #{quoted_name}"
        end

        private

        def opposite = direction == :asc ? :desc : :asc

        def opposite_nulls = nulls && (nulls == :last ? :first : :last)

        def placement = nulls && " NULLS #{nulls.to_s.upcase}"

        def quoted_table = quote_table_name(table_name)

        def quoted_name = quote_column_name(name)
      end
    end
  end
end
