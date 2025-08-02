# frozen_string_literal: true

module Migrations::Database
  module IntermediateDB
    def self.setup(db_connection)
      close
      @db = db_connection
    end

    def self.insert(sql, *parameters)
      @db.insert(sql, parameters)
    end

    def self.close
      @db.close if @db
    end
  end
end
