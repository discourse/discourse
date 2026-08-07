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

        # A key whose value can be null: the listing is split into segments at it when it
        # leads the order (see Order), and its nulls sort at one named end.
        def nullable? = nulls.expected?

        # A key the table cannot hand over as a column has to be selected under its name
        # before anything can order, compare or read it.
        def projected? = sql.present?

        # Reversing an order sends its nulls to the other end — which is also the only
        # placement a backward scan of an index built for the forward order can serve.
        def reverse = with(direction: direction.reversed, nulls: nulls.reversed)

        # The same key where nulls cannot appear: the band of a listing narrowed to the rows it
        # has values in. It names no placement there — an explicit one is a promise about rows
        # that do not exist, and it keeps the reading off any index that does not carry it.
        def without_nulls = with(nulls: nil)

        # How the database is asked to sort by this key, in the form an index for this order
        # can be scanned in.
        def ordering
          Arel.sql("#{identifier} #{direction.to_sql}#{nulls.to_sql}")
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

        attr_reader :nulls

        # Rebuilt from what was declared, never from the reading it produced: a key given
        # another direction reads its nulls another way.
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
