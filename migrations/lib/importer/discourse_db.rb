# frozen_string_literal: true

module Migrations::Importer
  module PgEncoderCache
    @encoders = {}

    ENCODER_MAP = {
      # Scalars
      "bool" => -> { PG::TextEncoder::Boolean.new },
      "date" => -> { PG::TextEncoder::Date.new },
      "float8" => -> { PG::TextEncoder::Float.new },
      "inet" => -> { PG::TextEncoder::Inet.new },
      "int4" => -> { PG::TextEncoder::Integer.new },
      "int8" => -> { PG::TextEncoder::Integer.new },
      "json" => -> { PG::TextEncoder::JSON.new },
      "jsonb" => -> { PG::TextEncoder::JSON.new },
      "text" => -> { PG::TextEncoder::String.new },
      "timestamp" => -> { PG::TextEncoder::String.new },
      "uuid" => -> { PG::TextEncoder::String.new },
      "varchar" => -> { PG::TextEncoder::String.new },
      # Ranges
      "int4range" => -> { PG::TextEncoder::String.new },
      # Arrays
      "inet[]" => -> { PG::TextEncoder::Array.new(name: "inet") },
      "int4[]" => -> { PG::TextEncoder::Array.new(name: "int4") },
      "text[]" => -> { PG::TextEncoder::Array.new(name: "text") },
      "varchar[]" => -> { PG::TextEncoder::Array.new(name: "varchar") },
    }

    def self.get_encoder(pg_type)
      pg_type = normalize_pg_type(pg_type)

      @encoders[pg_type] ||= begin
        factory = ENCODER_MAP[pg_type]
        raise "Unsupported PG type #{pg_type}" unless factory

        factory.call
      end
    end

    def self.normalize_pg_type(pg_type)
      pg_type.start_with?("_") ? "#{pg_type[1..]}[]" : pg_type
    end
  end

  class DiscourseDB
    QueryResult = Data.define(:rows, :column_count)

    COPY_BATCH_SIZE = 1_000
    SKIP_ROW_MARKER = :"$skip"

    def initialize
      @connection = PG::Connection.new(database_configuration)
      @connection.type_map_for_results = PG::BasicTypeMapForResults.new(@connection)
      @connection.field_name_type = :symbol
    end

    def copy_data(table_name, column_names, rows)
      quoted_column_name_list = column_names.map { |c| quote_identifier(c) }.join(",")
      sql = "COPY #{table_name} (#{quoted_column_name_list}) FROM STDIN"

      inserted_rows = []
      skipped_rows = []
      column_count = column_names.size
      data = Array.new(column_count)

      type_map = build_type_map(table_name, column_names)
      encoder = PG::TextEncoder::CopyRow.new(type_map:)

      rows.each_slice(COPY_BATCH_SIZE) do |sliced_rows|
        # TODO Maybe add error handling and check if all rows fail to insert, or only
        # some of them fail. Currently, if a single row fails to insert, then an exception
        # will stop the whole import. Which seems fine because ideally the import script
        # should ensure all data is valid. We might need to see how this works out in
        # actual migrations...
        @connection.transaction do
          @connection.copy_data(sql, encoder) do
            sliced_rows.each do |row|
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
          yield inserted_rows, skipped_rows

          inserted_rows.clear
          skipped_rows.clear
        end
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
      query = <<~SQL
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = $1
        ORDER BY ordinal_position
      SQL

      result = @connection.exec_params(query, [table_name])
      result.column_values(0).map(&:to_sym)
    end

    def query_array(sql, *params)
      query_result(sql, *params).rows
    end

    def query_result(sql, *params)
      @connection.send_query_params(sql, params)
      @connection.set_single_row_mode

      first_result = @connection.get_result
      return QueryResult.new(rows: Enumerator.new {}, column_count: 0) unless first_result

      column_count = first_result.nfields
      single_column = column_count == 1

      rows_enumerator =
        Enumerator.new do |y|
          first_result.stream_each_row { |row| single_column ? y << row[0] : y << row }
          first_result.clear

          while (result = @connection.get_result)
            result.stream_each_row { |row| single_column ? y << row[0] : y << row }
            result.clear
          end
        end

      QueryResult.new(rows: rows_enumerator, column_count:)
    end

    def close
      @connection.finish
    end

    private

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
      }.compact
    end

    def quote_identifier(identifier)
      PG::Connection.quote_ident(identifier.to_s)
    end

    def normalize_pg_type(pg_type)
      if pg_type.start_with?("_")
        "#{pg_type[1..]}[]" # '_int4' -> 'int4[]'
      else
        pg_type
      end
    end

    def build_type_map(table_name, column_names)
      sql = <<~SQL
        SELECT a.attname AS name,
               t.typname AS pg_type
        FROM pg_attribute a
             JOIN pg_type t ON a.atttypid = t.oid
        WHERE a.attrelid = $1::regclass
          AND a.attnum > 0
          AND NOT a.attisdropped
      SQL

      result = @connection.exec_params(sql, [table_name]).to_a
      column_type_map = result.to_h { |row| [row[:name].to_sym, row[:pg_type]] }

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
