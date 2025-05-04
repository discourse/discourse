# frozen_string_literal: true

require "pg"

module Migrations::Database::Adapter
  class Postgres
    def initialize(settings)
      @connection = PG::Connection.new(settings)
      @connection.type_map_for_results = PG::BasicTypeMapForResults.new(@connection)
      @connection.field_name_type = :symbol
      configure_connection
    end

    def exec(sql)
      @connection.exec(sql)
    end

    def query(sql, *params)
      @connection.send_query_params(sql, params)
      @connection.set_single_row_mode

      Enumerator.new do |y|
        while (result = @connection.get_result)
          result.stream_each { |row| y.yield(row) }
          result.clear
        end
      end
    end

    def query_first(sql)
      @connection.exec(sql).first
    end

    def query_value(sql, column)
      query_first(sql)[column]
    end

    def count(sql)
      query_first(sql).values.first.to_i
    end

    def close
      unless @connection&.finished?
        @connection.finish
        @connection = nil
      end
    end

    def reset
      @connection.reset
      configure_connection
    end

    def escape_string(str)
      @connection.escape_string(str)
    end

    private

    def configure_connection
      @connection.exec("SET client_min_messages TO WARNING")
    end
  end
end
