# frozen_string_literal: true

module Migrations
  module Database
    INTERMEDIATE_DB_SCHEMA_PATH = File.join(Migrations.root_path, "db", "intermediate_db_schema")
    UPLOADS_DB_SCHEMA_PATH = File.join(Migrations.root_path, "db", "uploads_db_schema")

    def self.migrate(db_path, migrations_path:)
      Migrator.new(db_path).migrate(migrations_path)
    end

    def self.reset!(db_path)
      Migrator.new(db_path).reset!
    end

    def self.connect(path)
      connection = Connection.new(path:)
      yield(connection)
    ensure
      connection.close if connection
    end
  end
end
