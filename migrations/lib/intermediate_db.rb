# frozen_string_literal: true

require "singleton"

module Migrations
  class IntermediateDb
    def self.instance
      @__instance__ ||= new
    end

    def initialize
      @db = nil
    end

    def setup(db_connection)
      @db = db_connection unless @db
    end

    def insert(sql, *parameters)
      @db.insert(sql, *parameters)
    end
  end
end
