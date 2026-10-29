# frozen_string_literal: true

require "pg"

module Migrations
  module Converters
    module Adapter
      class Postgres
        include Conversion::PartitionSource

        DiscardedError = Database::ManagedConnection::DiscardedError

        def initialize(settings)
          @connection =
            Database::ManagedConnection.open(
              Database::Drivers::Postgres.new(settings, field_names: :symbol, quiet: true),
            )
        end

        def exec(sql)
          @connection.with { |connection| connection.exec(sql) }
        end

        def query(sql, *params)
          Database::PostgresStream.new(@connection, sql, params)
        end

        def query_value(sql)
          query_first_row(sql)&.values&.first
        end

        def count(sql)
          query_value(sql).to_i
        end

        # Reads every row of `table`, optionally narrowed by the `where` body (nil
        # reads the whole table) and sorted by `order` (a column or array of them).
        # Backs the `reads_table` default in a step's source; a partitioned step
        # orders by its key so each worker writes its shard in key order — sequential
        # SQLite index inserts in the shard and, later, in the merge.
        def select_all(table, where: nil, order: nil)
          query(
            "SELECT * FROM #{quote_identifier(table)}" \
              "#{where_clause(where)}#{order_clause(order)}",
          )
        end

        # The row count of `table`, optionally narrowed by `where`. Backs
        # `reads_table`'s default `max_progress`.
        def count_all(table, where: nil)
          count("SELECT COUNT(*) FROM #{quote_identifier(table)}#{where_clause(where)}")
        end

        # The following back {Conversion::Partitioner}; see its primitive list.

        # The key's min and max. Answered from the key's index, so this stays cheap
        # and doesn't scan the table.
        def partition_bounds(column, from, base)
          row =
            query_first_row(
              "SELECT MIN(#{column}) AS min, MAX(#{column}) AS max " \
                "FROM #{quote_identifier(from)}#{where_clause(base)}",
            )
          [row[:min], row[:max]]
        end

        # The planner's row estimate (`pg_class.reltuples`), so the partitioner can
        # tell a dense key from a sparse one without a COUNT(*) scan. It's the whole
        # table's estimate and ignores `base`, which is fine for a magnitude check;
        # it is -1 before the table is analysed.
        def estimated_row_count(from)
          query_value(
            "SELECT reltuples::bigint FROM pg_class WHERE oid = #{quote(from)}::regclass",
          ).to_i
        end

        # The chunk lower bounds, computed in SQL: `NTILE` splits the sorted key
        # into `count` equal-sized buckets and `DISTINCT ON` takes each bucket's
        # first value, so only the boundaries cross the wire, not the whole key
        # column. Works the same for a scalar or a composite key. This is the
        # optional fast path the {Conversion::Partitioner} prefers over streaming.
        def boundaries_by_scan(key, from, base, count)
          select = Array(key).join(", ")
          rows = query(<<~SQL)
            SELECT DISTINCT ON (bucket) #{select}
            FROM (
              SELECT #{select}, NTILE(#{count}) OVER (ORDER BY #{select}) AS bucket
              FROM #{quote_identifier(from)}#{where_clause(base)}
            ) buckets
            ORDER BY bucket, #{select}
          SQL
          rows.map { |row| boundary_value(row, key) }.uniq
        end

        # The WHERE body limiting a query to the chunk `[lower, upper)` of `key`
        # (one column, or an array for a composite key), AND-ed with `base`. A
        # composite key compares as a row value: `(a, b) >= (a0, b0)`.
        def chunk_filter(key, lower, upper, base: nil)
          return base if lower.nil?

          expression = key_expression(key)
          conditions = ["#{expression} >= #{value_expression(key, lower)}"]
          conditions << "#{expression} < #{value_expression(key, upper)}" unless upper.nil?
          [base, *conditions].compact.join(" AND ")
        end

        def close
          @connection.close
        end

        def encode_array(array)
          @array_encoder ||= PG::TextEncoder::Array.new

          @array_encoder.encode(array)
        end

        private

        def query_first_row(sql)
          exec(sql).first
        end

        def escape_string(str)
          @connection.with { |connection| connection.escape_string(str) }
        end

        # `" WHERE <filter>"`, or "" when there's no filter — so a missing filter
        # reads the whole table instead of leaning on a `WHERE TRUE` that not every
        # dialect accepts.
        def where_clause(filter)
          filter ? " WHERE #{filter}" : ""
        end

        # `" ORDER BY <cols>"`, or "" when unordered. Accepts a column or an array.
        def order_clause(order)
          order ? " ORDER BY #{Array(order).join(", ")}" : ""
        end

        def boundary_value(row, key)
          return row.values.first unless key.is_a?(Array)
          key.map { |part| row[part.to_sym] }
        end

        def key_expression(key)
          key.is_a?(Array) ? "(#{key.join(", ")})" : key.to_s
        end

        def value_expression(key, value)
          return quote(value) unless key.is_a?(Array)
          "(#{value.map { |part| quote(part) }.join(", ")})"
        end

        def quote(value)
          value.is_a?(Numeric) ? value.to_s : "'#{escape_string(value.to_s)}'"
        end

        def quote_identifier(value)
          @connection.with { |connection| connection.quote_ident(value) }
        end
      end
    end
  end
end
