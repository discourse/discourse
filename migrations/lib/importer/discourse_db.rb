# frozen_string_literal: true

module Migrations::Importer
  class DiscourseDB
    COPY_BATCH_SIZE = 1_000

    def initialize
      @encoder = PG::TextEncoder::CopyRow.new
      @connection = PG::Connection.new(database_configuration)
      @connection.type_map_for_results = PG::BasicTypeMapForResults.new(@connection)
    end

    def copy_data(table_name, column_names, rows)
      sql = "COPY #{table_name} (#{column_names.map { |c| "\"#{c}\"" }.join(",")}) FROM STDIN"

      rows.each_slice(COPY_BATCH_SIZE) do |sliced_rows|
        @connection.copy_data(sql, @encoder) do
          sliced_rows.each do |row|
            data = column_names.map { |c| row[c] }
            @connection.put_copy_data(data)
          end
        end
      end
    end

    def last_id_of(table_name)
      query = <<~SQL
        SELECT COALESCE(MAX(id), 0)
          FROM #{PG::Connection.quote_ident(table_name.to_s)}
      SQL
      @connection.exec(query).getvalue(0, 0)
    end

    def fix_last_id_of(table_name)
      table_name = PG::Connection.quote_ident(table_name.to_s)
      query = <<~SQL
        SELECT SETVAL(PG_GET_SERIAL_SEQUENCE('#{table_name}', 'id'), MAX(id))
          FROM #{table_name};
      SQL

      @connection.exec(query)
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
        username: username || db_config[:username],
        password: password || db_config[:password],
        dbname: db_config[:database],
      }.compact
    end
  end
end
