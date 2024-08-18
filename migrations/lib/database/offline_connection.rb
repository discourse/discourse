# frozen_string_literal: true

module Migrations::Database
  class OfflineConnection
    def initialize
      @parametrized_insert_statements = []
    end

    def close
      # no-op
    end

    def insert(sql, *parameters)
      @parametrized_insert_statements << [sql, parameters]
    end

    def parametrized_insert_statements
      @parametrized_insert_statements
    end

    def clear!
      @parametrized_insert_statements.clear
    end
  end
end
