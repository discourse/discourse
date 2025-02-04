# frozen_string_literal: true

module Migrations::Database
  class OfflineConnection
    def initialize
      @parametrized_insert_statements = []
    end

    def close
      @parametrized_insert_statements = nil
    end

    def closed?
      @parametrized_insert_statements.nil?
    end

    def insert(sql, parameters = [])
      @parametrized_insert_statements << [sql, parameters]
    end

    def parametrized_insert_statements
      @parametrized_insert_statements
    end

    def clear!
      @parametrized_insert_statements.clear if @parametrized_insert_statements
    end
  end
end
