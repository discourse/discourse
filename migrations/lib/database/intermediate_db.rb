# frozen_string_literal: true

require "singleton"

module Migrations::Database
  module IntermediateDB
    def self.setup(db_connection)
      @db = db_connection
    end

    def self.insert(sql, *parameters)
      @db.insert(sql, *parameters)
    end

    def self.close
      @db.close if @db
    end

    def self.path
      @db&.path
    end
  end
end
