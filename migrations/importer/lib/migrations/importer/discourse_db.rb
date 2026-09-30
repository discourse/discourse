# frozen_string_literal: true

module Migrations
  module Importer
    class DiscourseDB
      QueryResult = Data.define(:rows, :column_count)

      # amortizes the per-commit fsync; measured throughput plateaus between
      # 20k and 100k for both narrow and text-heavy tables, while the batch
      # is also what a crash can lose and what stays in memory between commits
      COPY_BATCH_SIZE = 20_000
      SKIP_ROW_MARKER = :$skip

      def initialize
        @connection = PG::Connection.new(database_configuration)
        @connection.type_map_for_results = PG::BasicTypeMapForResults.new(@connection)
        @columns = {}
        configure_session
      end

      # Inserts `rows` in transactional batches and yields `inserted, skipped`
      # after each commit. With `on_failed_row`, a failing batch is bisected
      # until the bad rows are isolated: good rows are still inserted, each bad
      # row is handed to the callback and left out (no ID mapping, so a later
      # run retries it). A batch whose rows all fail aborts instead — that's
      # not bad data, that's something systemic.
      def copy_data(table_name, column_names, rows, on_failed_row: nil, &on_commit)
        quoted_column_name_list = column_names.map { |c| quote_identifier(c) }.join(",")
        sql = "COPY #{table_name} (#{quoted_column_name_list}) FROM STDIN"

        type_map = build_type_map(table_name, column_names)
        encoder = PG::TextEncoder::CopyRow.new(type_map:)

        row_offset = 0
        rows.each_slice(COPY_BATCH_SIZE) do |sliced_rows|
          if on_failed_row
            failed = []
            # percent-level failure is not bad data, it's something systemic;
            # the cap also bounds the bisection work for a broken batch
            failed_limit = [sliced_rows.size / 100, 10].max
            insert_rows_and_collect_failures(
              sql,
              encoder,
              table_name,
              column_names,
              sliced_rows,
              failed,
              failed_limit,
              &on_commit
            )

            if failed.any?
              insertable_count = sliced_rows.count { |row| !row[SKIP_ROW_MARKER] }
              first_error = failed.first.last

              if insertable_count > 1 && failed.size == insertable_count
                raise first_error.class,
                      "all #{insertable_count} rows of a batch failed to insert " \
                        "(table #{table_name}, rows #{row_offset + 1}-#{row_offset + sliced_rows.size} of this step): " \
                        "#{first_error.message.strip}",
                      first_error.backtrace
              end

              failed.each { |row, error| on_failed_row.call(row, error) }
            end
          else
            begin
              insert_batch(sql, encoder, column_names, sliced_rows, &on_commit)
            rescue PG::Error => e
              raise e.class,
                    "#{e.message.strip} (table #{table_name}, rows #{row_offset + 1}-#{row_offset + sliced_rows.size} of this step)",
                    e.backtrace
            end
          end

          row_offset += sliced_rows.size
        end

        nil
      end

      def last_id_of(table_name)
        query = <<~SQL
          SELECT COALESCE(MAX(id), 0)
            FROM #{quote_identifier(table_name)}
          WHERE id > 0
        SQL

        result = @connection.exec(query)
        result.getvalue(0, 0)
      end

      def fix_last_id_of(table_name)
        table_name = quote_identifier(table_name)
        query = <<~SQL
          SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('#{table_name}', 'id'), MAX(id))
            FROM #{table_name}
          HAVING MAX(id) > 0
        SQL

        @connection.exec(query)
        nil
      end

      def column_names(table_name)
        columns_of(table_name).keys
      end

      def query_array(sql, *params)
        query_result(sql, *params).rows.to_a
      end

      def query_result(sql, *params)
        @connection.send_query_params(sql, params)
        @connection.set_single_row_mode

        first_result = @connection.get_result
        return QueryResult.new(rows: [], column_count: 0) unless first_result

        column_count = first_result.nfields
        single_column = column_count == 1

        rows = RowStream.new(@connection, first_result, single_column)
        QueryResult.new(rows:, column_count:)
      end

      def close
        @connection.finish
      end

      # Streams rows in single-row mode. Safe to abandon: when iteration
      # stops early, the remaining server results are drained so the next
      # query on the connection still works. Not a fiber-backed Enumerator
      # on purpose — under external iteration (.next) its ensure would only
      # run at GC time, when it could consume another query's results.
      class RowStream
        include Enumerable

        def initialize(connection, first_result, single_column)
          @connection = connection
          @first_result = first_result
          @single_column = single_column
        end

        def each(&block)
          return to_enum(:each) unless block_given?
          raise "the result stream can only be consumed once" if @consumed
          @consumed = true

          result = @first_result
          while result
            result.stream_each_row { |row| block.call(@single_column ? row[0] : row) }
            result.clear
            result = @connection.get_result
          end
        ensure
          while (pending = @connection.get_result)
            pending.clear
          end
        end
      end

      private

      def insert_batch(sql, encoder, column_names, batch, &on_commit)
        inserted_rows = []
        skipped_rows = []
        column_count = column_names.size
        data = Array.new(column_count)

        @connection.transaction do
          @connection.copy_data(sql, encoder) do
            batch.each do |row|
              if row[SKIP_ROW_MARKER]
                skipped_rows << row
                next
              end

              i = 0
              while i < column_count
                data[i] = row[column_names[i]]
                i += 1
              end

              @connection.put_copy_data(data)
              inserted_rows << row
            end
          end

          # give the caller a chance to do some work when a batch has been committed,
          # for example, to store ID mappings
          on_commit.call(inserted_rows, skipped_rows)
        end

        nil
      end

      # Collects the isolated `[row, error]` failures into `failed` instead of
      # raising. Bisects on failure, so the cost is O(log batch) extra
      # attempts per bad row and the good rows around it still make it in.
      # Gives up once `failed_limit` rows have been isolated.
      def insert_rows_and_collect_failures(
        sql,
        encoder,
        table_name,
        column_names,
        batch,
        failed,
        failed_limit,
        &on_commit
      )
        insert_batch(sql, encoder, column_names, batch, &on_commit)
        nil
      rescue PG::Error => e
        insertable = batch.reject { |row| row[SKIP_ROW_MARKER] }
        raise if insertable.empty?

        if insertable.size == 1
          # marker-skipped rows can still carry ID mappings; nothing was
          # committed for them yet in this sub-batch
          skipped = batch - insertable
          on_commit.call([], skipped) if skipped.any?

          failed << [insertable.first, e]
          if failed.size > failed_limit
            raise e.class,
                  "too many rows of a batch failed to insert, giving up after #{failed.size} " \
                    "(table #{table_name}): #{e.message.strip}",
                  e.backtrace
          end
          return
        end

        mid = batch.size / 2
        insert_rows_and_collect_failures(
          sql,
          encoder,
          table_name,
          column_names,
          batch[...mid],
          failed,
          failed_limit,
          &on_commit
        )
        insert_rows_and_collect_failures(
          sql,
          encoder,
          table_name,
          column_names,
          batch[mid..],
          failed,
          failed_limit,
          &on_commit
        )
      end

      # timestamps arrive as the literal NOW(), which Postgres evaluates in
      # the session timezone, and server-side timeouts must not kill long
      # COPY batches or MAX(id) scans
      def configure_session
        @connection.exec(<<~SQL)
          SET TimeZone = 'UTC';
          SET statement_timeout = 0;
          SET idle_in_transaction_session_timeout = 0;
        SQL
      end

      def database_configuration
        db_config = ActiveRecord::Base.connection_db_config.configuration_hash

        # credentials for PostgreSQL in CI environment
        if Rails.env.test?
          username = ENV["PGUSER"]
          password = ENV["PGPASSWORD"]
        end

        {
          host: db_config[:host],
          port: db_config[:port],
          user: db_config[:username] || username,
          password: db_config[:password] || password,
          dbname: db_config[:database],
          application_name: "discourse-migrations-importer",
        }.compact
      end

      def quote_identifier(identifier)
        PG::Connection.quote_ident(identifier.to_s)
      end

      # resolved through the search_path (regclass), so a same-named table in
      # another schema can't shadow the one COPY writes to
      def columns_of(table_name)
        @columns[table_name] ||= begin
          sql = <<~SQL
            SELECT a.attname AS name,
                   t.typname AS pg_type
            FROM pg_attribute a
                 JOIN pg_type t ON a.atttypid = t.oid
            WHERE a.attrelid = $1::regclass
              AND a.attnum > 0
              AND NOT a.attisdropped
            ORDER BY a.attnum
          SQL

          @connection
            .exec_params(sql, [table_name.to_s])
            .to_a
            .to_h { |row| [row["name"].to_sym, row["pg_type"]] }
        end
      end

      def build_type_map(table_name, column_names)
        column_type_map = columns_of(table_name)

        encoders =
          column_names.map do |column_name|
            pg_type = column_type_map[column_name]
            raise "Column #{column_name} not found in table #{table_name}" unless pg_type

            PgEncoderCache.get_encoder(pg_type)
          end

        PG::TypeMapByColumn.new(encoders)
      end
    end
  end
end
