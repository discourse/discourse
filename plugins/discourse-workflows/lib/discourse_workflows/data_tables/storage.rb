# frozen_string_literal: true

module DiscourseWorkflows
  module DataTables
    class Storage
      SCHEMA_TYPES = {
        "string" => :text,
        "number" => :float,
        "boolean" => :boolean,
        "date" => :timestamp,
      }.freeze

      RESERVED_COLUMN_NAMES = Types::SYSTEM_COLUMN_NAMES

      TABLE_NAME_PREFIX = "discourse_workflows_data_table_"
      TABLE_NAME_SUFFIX = "_rows"

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
          "#{TABLE_NAME_PREFIX}#{Integer(data_table_id)}#{TABLE_NAME_SUFFIX}"
        end

        def table_name_like_pattern
          "#{TABLE_NAME_PREFIX}%#{TABLE_NAME_SUFFIX}"
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
          pattern = table_name_like_pattern
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
          DB
            .query_single(
              "SELECT pg_total_relation_size(to_regclass(:table_name))",
              table_name: quoted_table(data_table_id),
            )
            .first
            .to_i
        end

        def batch_stats(data_table_ids)
          return {} if data_table_ids.empty?

          queries = data_table_ids.map { |id| <<~SQL }
            SELECT #{Integer(id)} AS data_table_id,
                   COUNT(*) AS row_count,
                   pg_total_relation_size(#{connection.quote(quoted_table(id))}::regclass) AS size
            FROM #{quoted_table(id)}
          SQL

          DB
            .query(queries.join(" UNION ALL "))
            .to_h { |row| [row.data_table_id, { size: row.size, row_count: row.row_count }] }
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
end
