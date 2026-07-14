# frozen_string_literal: true

require "date"
require "extralite"
require "fileutils"
require "ipaddr"
require "json"

module Migrations
  module Database
    INTERMEDIATE_DB_SCHEMA_PATH = File.join(Migrations.root_path, "db", "intermediate_db_schema")
    MAPPINGS_DB_SCHEMA_PATH = File.join(Migrations.root_path, "db", "mappings_db_schema")
    UPLOADS_DB_SCHEMA_PATH = File.join(Migrations.root_path, "db", "uploads_db_schema")

    def self.migrate(db_path, migrations_path:)
      Migrator.new(db_path).migrate(migrations_path)
    end

    # A WAL-mode database is three files: the main file plus its `-wal` and `-shm`
    # sidecars.
    def self.database_files(db_path)
      [db_path, "#{db_path}-wal", "#{db_path}-shm"]
    end

    # Deletes the database and its sidecar files; no error if any are missing.
    def self.delete_database(db_path)
      FileUtils.rm_f(database_files(db_path))
    end

    def self.connect(path)
      connection = Connection.new(path:)
      return connection unless block_given?

      begin
        yield(connection)
      ensure
        connection.close
      end
      nil
    end

    def self.schema_path(type)
      case type
      when "intermediate_db"
        INTERMEDIATE_DB_SCHEMA_PATH
      when "mappings_db"
        MAPPINGS_DB_SCHEMA_PATH
      when "uploads_db"
        UPLOADS_DB_SCHEMA_PATH
      else
        raise "Unknown type: #{type}"
      end
    end

    def self.format_datetime(value)
      value&.utc&.iso8601
    end

    def self.format_date(value)
      value&.to_date&.iso8601
    end

    def self.format_boolean(value)
      return nil if value.nil?
      value ? 1 : 0
    end

    def self.format_ip_address(value)
      return nil if value.blank?
      # `PG::BasicTypeMapForResults` decodes `inet` columns into `IPAddr`
      # objects, which `IPAddr.new` rejects
      return value.to_s if value.is_a?(IPAddr)
      IPAddr.new(value).to_s
    rescue ArgumentError
      nil
    end

    def self.to_blob(value)
      return nil if value.blank?
      Extralite::Blob.new(value)
    end

    def self.to_json(value)
      return nil if value.nil?
      JSON.generate(value)
    end

    def self.to_date(text)
      text.present? ? Date.parse(text) : nil
    end

    def self.to_datetime(text)
      text.present? ? DateTime.parse(text) : nil
    end

    def self.to_boolean(value)
      value == 1
    end
  end
end
