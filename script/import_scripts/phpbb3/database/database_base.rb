module ImportScripts::PhpBB3
  class DatabaseBase
    # @param database_client [Mysql2::Client]
    # @param database_settings [ImportScripts::PhpBB3::DatabaseSettings]
    def initialize(database_client, database_settings)
      @database_client = database_client

      @batch_size = database_settings.batch_size
      @table_prefix = database_settings.table_prefix
    end

    protected

    # Executes a database query.
    def query(sql, *last_columns)
      rows = @database_client.query(sql, cache_rows: true, symbolize_keys: true)
      return rows if last_columns.length == 0

      result = [rows]
      last_row = find_last_row(rows)

      last_columns.each { |column| result.push(last_row ? last_row[column] : nil) }
      result
    end

    # Executes a database query and returns the value of the 'count' column.
    def count(sql)
      query(sql).first[:count]
    end

    def escape(value)
      @database_client.escape(value)
    end

    private

    def find_last_row(rows)
      last_index = rows.size - 1

      rows.each_with_index do |row, index|
        return row if index == last_index
      end

      nil
    end
  end
end
