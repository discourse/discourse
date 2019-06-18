# frozen_string_literal: true

require 'mysql2'

module ImportScripts::PhpBB3
  class Database
    # @param database_settings [ImportScripts::PhpBB3::DatabaseSettings]
    def self.create(database_settings)
      Database.new(database_settings).create_database
    end

    # @param database_settings [ImportScripts::PhpBB3::DatabaseSettings]
    def initialize(database_settings)
      @database_settings = database_settings
      @database_client = create_database_client
    end

    # @return [ImportScripts::PhpBB3::Database_3_0 | ImportScripts::PhpBB3::Database_3_1]
    def create_database
      version = get_phpbb_version

      if version.start_with?('3.0')
        require_relative 'database_3_0'
        Database_3_0.new(@database_client, @database_settings)
      elsif version.start_with?('3.1')
        require_relative 'database_3_1'
        Database_3_1.new(@database_client, @database_settings)
      else
        raise UnsupportedVersionError, <<~MSG
          Unsupported version (#{version}) of phpBB detected.
          Currently only 3.0.x and 3.1.x are supported by this importer.
        MSG
      end
    end

    protected

    def create_database_client
      Mysql2::Client.new(
        host: @database_settings.host,
        port: @database_settings.port,
        username: @database_settings.username,
        password: @database_settings.password,
        database: @database_settings.schema,
        reconnect: true
      )
    end

    def get_phpbb_version
      table_prefix = @database_settings.table_prefix

      @database_client.query(<<-SQL, cache_rows: false, symbolize_keys: true).first[:config_value]
        SELECT config_value
        FROM #{table_prefix}config
        WHERE config_name = 'version'
      SQL
    end
  end

  class UnsupportedVersionError < RuntimeError
  end
end
