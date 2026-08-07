# frozen_string_literal: true

module JsonApiKit
  module Declarations
    # One way a resource lets its listings be ordered: the name a client sorts by, and what the
    # database orders on — a column of the table, or the SQL that produces the value and the joins
    # that SQL needs. It hands over a pagination key when asked, in the direction of the request.
    #
    # The model arrives with that request rather than being held here, so declaring a sort loads
    # nothing.
    class Sort
      attr_reader :name

      def initialize(name, column: nil, sql: nil, joins: [], nulls: nil)
        @name = name.to_s
        @column = column
        @sql = sql
        @joins = Array(joins)
        @nulls = nulls
      end

      def key(model:, direction:)
        Pagination::Keyset::Key.new(
          attribute,
          model:,
          direction:,
          sql:,
          joins:,
          nulls: placement(model),
        )
      end

      private

      attr_reader :column, :sql, :joins, :nulls

      # The name the value is read under: the column it comes from, or — for a value the table
      # cannot hand over — the name it is projected as, which a client's own spelling of a related
      # field cannot be.
      def attribute = (column || name.tr(".", "_")).to_sym

      # Where this sort's nulls go: what was declared, and otherwise last for anything that can be
      # null, since a value with no placement is one a page can skip (see Pagination::Nulls). A
      # value the table has no column for is one we know nothing about — an expression over a join
      # usually can be null — so it counts as nullable too.
      def placement(model)
        return nulls if nulls
        column = model.columns_hash[attribute.to_s]
        return :last unless column
        :last if column.null
      end
    end
  end
end
