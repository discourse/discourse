# frozen_string_literal: true

require "pg"

module Migrations
  module Converters
    module Adapter
      class Postgres
        class DiscardedError < StandardError
        end

        def initialize(settings)
          @connection = PG::Connection.new(settings)
          @connection.type_map_for_results = PG::BasicTypeMapForResults.new(@connection)
          @connection.field_name_type = :symbol
          configure_connection

          @fork_hook = ForkManager.after_fork_child { discard! }
        end

        def exec(sql)
          connection.exec(sql)
        end

        def query(sql, *params)
          connection.send_query_params(sql, params)
          connection.set_single_row_mode

          Enumerator.new do |y|
            while (result = connection.get_result)
              result.stream_each { |row| y.yield(row) }
              result.clear
            end
          end
        end

        def query_first_row(sql)
          connection.exec(sql).first
        end

        def query_value(sql, column = nil)
          if (row = query_first_row(sql))
            column ? row[column.to_sym] : row.values.first
          else
            nil
          end
        end

        def count(sql)
          query_value(sql).to_i
        end

        # Reads every row of `table`, optionally narrowed by the `where` body
        # (nil reads the whole table). Backs the `reads_table` default in a step's
        # source; the table name is quoted here so the SQL stays in the adapter.
        def select_all(table, where: nil)
          query("SELECT * FROM #{connection.quote_ident(table)}#{where_clause(where)}")
        end

        # The row count of `table`, optionally narrowed by `where`. Backs
        # `reads_table`'s default `max_progress`.
        def count_all(table, where: nil)
          count("SELECT COUNT(*) FROM #{connection.quote_ident(table)}#{where_clause(where)}")
        end

        def close
          @connection.finish if @connection && !@connection.finished?
          @connection = nil

          if @fork_hook
            ForkManager.remove_after_fork_child(@fork_hook)
            @fork_hook = nil
          end
        end

        # Forked worker processes inherit the connection's socket. When such a
        # process exits, the pg gem's cleanup sends a libpq Terminate message
        # over that socket and the server closes the session — including for
        # the main process, which still uses it. Redirecting the inherited
        # file descriptor to /dev/null makes the cleanup harmless; calling
        # `#finish` or `#close` instead would send the very message this
        # needs to suppress.
        def discard!
          begin
            @connection&.socket_io&.reopen(IO::NULL)
          rescue StandardError
            # When there's no usable socket (already closed, failed connection,
            # older pg gem), there's also nothing the cleanup could corrupt.
          end

          @connection = nil
          @discarded = true
        end

        def reset
          connection.reset
          configure_connection
        end

        def escape_string(str)
          connection.escape_string(str)
        end

        def encode_array(array)
          @array_encoder ||= PG::TextEncoder::Array.new

          @array_encoder.encode(array)
        end

        private

        # `" WHERE <filter>"`, or "" when there's no filter — so a missing filter
        # reads the whole table instead of leaning on a `WHERE TRUE` that not every
        # dialect accepts.
        def where_clause(filter)
          filter ? " WHERE #{filter}" : ""
        end

        def connection
          if @discarded
            raise DiscardedError,
                  "The source DB connection was discarded in this worker process. " \
                    "Only sources may query the source DB; processors must work " \
                    "with the items they receive."
          end

          @connection
        end

        def configure_connection
          @connection.exec("SET client_min_messages TO WARNING")
        end
      end
    end
  end
end
