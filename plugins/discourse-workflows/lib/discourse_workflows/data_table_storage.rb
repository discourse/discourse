# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableStorage
    SQL_TYPES = {
      "string" => "TEXT",
      "number" => "DOUBLE PRECISION",
      "boolean" => "BOOLEAN",
      "date" => "TIMESTAMP",
    }.freeze

    LOCK_TIMEOUT_MS = 5_000

    class << self
      def table_name(data_table_id)
        "discourse_workflows_data_table_#{data_table_id}_rows"
      end

      def create_table!(data_table)
        return if connection.data_source_exists?(table_name(data_table.id))

        definitions = [
          "#{quoted_column("id")} BIGSERIAL PRIMARY KEY",
          "#{quoted_column("created_at")} TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP",
          "#{quoted_column("updated_at")} TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP",
          *column_definitions(data_table.columns),
        ]

        DB.exec(<<~SQL)
            CREATE TABLE #{quoted_table(data_table.id)} (
              #{definitions.join(",\n  ")}
            )
          SQL
      end

      def drop_table!(data_table_id)
        return unless connection.data_source_exists?(table_name(data_table_id))

        DB.exec("DROP TABLE #{quoted_table(data_table_id)}")
      end

      def total_size_bytes
        pattern = table_name("%")
        DB.query_single(<<~SQL, pattern: pattern).first.to_i
            SELECT COALESCE(SUM(pg_relation_size(c.oid)), 0)
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = current_schema()
              AND c.relname LIKE :pattern
              AND c.relkind = 'r'
          SQL
      end

      def size_bytes(data_table_id)
        batch_size_bytes([data_table_id]).fetch(data_table_id, 0)
      end

      def batch_size_bytes(data_table_ids)
        return {} if data_table_ids.empty?

        names = data_table_ids.map { |id| table_name(id) }
        DB
          .query(<<~SQL, names: names)
            SELECT c.relname, pg_relation_size(c.oid) AS size_bytes
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = current_schema()
              AND c.relname = ANY(ARRAY[:names])
              AND c.relkind = 'r'
          SQL
          .to_h do |row|
            id =
              row
                .relname
                .delete_prefix("discourse_workflows_data_table_")
                .delete_suffix("_rows")
                .to_i
            [id, row.size_bytes.to_i]
          end
      end

      def quoted_table(data_table_id)
        connection.quote_table_name(table_name(data_table_id))
      end

      def quoted_column(name)
        connection.quote_column_name(name)
      end

      def add_column!(data_table_id, column)
        with_lock_timeout do
          DB.exec(
            "ALTER TABLE #{quoted_table(data_table_id)} ADD COLUMN #{quoted_column(column_name(column))} #{sql_type(column_type(column))}",
          )
        end
      end

      def rename_column!(data_table_id, old_name, new_name)
        with_lock_timeout do
          DB.exec(
            "ALTER TABLE #{quoted_table(data_table_id)} RENAME COLUMN #{quoted_column(old_name)} TO #{quoted_column(new_name)}",
          )
        end
      end

      def drop_column!(data_table_id, column_name)
        with_lock_timeout do
          DB.exec(
            "ALTER TABLE #{quoted_table(data_table_id)} DROP COLUMN #{quoted_column(column_name)}",
          )
        end
      end

      private

      def with_lock_timeout
        DB.exec("SET LOCAL lock_timeout = '#{LOCK_TIMEOUT_MS}ms'")
        yield
      rescue PG::LockNotAvailable
        raise DataTableValidationError,
              "Could not acquire lock on the data table. It may be in use — please try again."
      end

      def connection
        ActiveRecord::Base.connection
      end

      def column_definitions(columns)
        columns.map do |column|
          "#{quoted_column(column_name(column))} #{sql_type(column_type(column))}"
        end
      end

      def sql_type(type)
        SQL_TYPES.fetch(type) do
          raise DataTableValidationError, "Unsupported column type '#{type}'"
        end
      end

      def column_name(column)
        DiscourseWorkflows::DataTable.column_name(column)
      end

      def column_type(column)
        DiscourseWorkflows::DataTable.column_type(column)
      end
    end
  end
end
