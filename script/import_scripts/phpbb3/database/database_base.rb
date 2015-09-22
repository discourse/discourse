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
    def query(sql)
      @database_client.query(sql, cache_rows: false, symbolize_keys: true)
    end

    # Executes a database query and returns the value of the 'count' column.
    def count(sql)
      query(sql).first[:count]
    end
  end
end
