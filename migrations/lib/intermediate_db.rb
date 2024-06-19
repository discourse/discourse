# frozen_string_literal: true

module Migrations
  module IntermediateDB
    def self.migrate(db_path, migrations_path: nil)
      Migrator.new(db_path, migrations_path).migrate
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
