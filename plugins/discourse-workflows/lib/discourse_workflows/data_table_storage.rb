# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableStorage
    SCHEMA_TYPES = {
      "string" => :text,
      "number" => :float,
      "boolean" => :boolean,
      "date" => :timestamp,
    }.freeze

    LOCK_TIMEOUT_MS = 5_000

    RESERVED_COLUMN_NAMES = %w[id created_at updated_at].freeze

    REVERSE_TYPE_MAP = {
      "int8" => "number",
      "int4" => "number",
      "float8" => "number",
      "text" => "string",
      "varchar" => "string",
      "bool" => "boolean",
      "timestamp" => "date",
      "timestamptz" => "date",
    }.freeze

    class << self
      def table_name(data_table_id)
        "discourse_workflows_data_table_#{data_table_id}_rows"
      end

      def columns(data_table_id)
        name = table_name(data_table_id)
        DB
          .query(<<~SQL, table_name: name)
            SELECT a.attname AS name, t.typname AS pg_type
            FROM pg_attribute a
            JOIN pg_class c ON c.oid = a.attrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            JOIN pg_type t ON t.oid = a.atttypid
            WHERE c.relname = :table_name
              AND n.nspname = current_schema()
              AND a.attnum > 0
              AND NOT a.attisdropped
            ORDER BY a.attnum
          SQL
          .map do |row|
            mapped_type =
              REVERSE_TYPE_MAP[row.pg_type] ||
                raise(ArgumentError, "Unmapped PG type '#{row.pg_type}' for column '#{row.name}'")
            { "name" => row.name, "type" => mapped_type }
          end
      end

      def create_table!(data_table, columns: [])
        name = table_name(data_table.id)
        return if connection.data_source_exists?(name)

        connection.create_table(name) do |t|
          columns.each do |column|
            t.column DataTable.column_name(column), schema_type(DataTable.column_type(column))
          end
          t.timestamps default: -> { "CURRENT_TIMESTAMP" }, null: false
        end
      end

      def drop_table!(data_table_id)
        name = table_name(data_table_id)
        return unless connection.data_source_exists?(name)

        connection.drop_table(name)
      end

      def total_size_bytes
        pattern = table_name("%")
        DB.query_single(<<~SQL, pattern: pattern).first.to_i
            SELECT COALESCE(SUM(pg_total_relation_size(c.oid)), 0)
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
            SELECT c.relname, pg_total_relation_size(c.oid) AS size_bytes
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

      private

      def connection
        ActiveRecord::Base.connection
      end

      def schema_type(type)
        SCHEMA_TYPES.fetch(type) { raise ArgumentError, "Unsupported column type '#{type}'" }
      end
    end
  end
end
