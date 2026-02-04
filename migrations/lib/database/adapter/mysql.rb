# frozen_string_literal: true

require "mysql2"

module Migrations::Database::Adapter
  class Mysql
    def initialize(settings)
      @settings = settings
      connect
      configure_connection
    end

    def exec(sql)
      with_reconnect { @connection.query(sql) }
    end

    def query(sql, *params)
      final_sql = params.empty? ? sql : interpolate_params(sql, params)
      results =
        with_reconnect do
          @connection.query(final_sql, stream: true, cache_rows: false, symbolize_keys: true)
        end
      Enumerator.new { |y| results.each { |row| y.yield(row) } }
    end

    def query_first_row(sql, *params)
      final_sql = params.empty? ? sql : interpolate_params(sql, params)
      with_reconnect { @connection.query(final_sql, symbolize_keys: true) }.first
    end

    def query_value(sql, *params)
      row = query_first_row(sql, *params)
      row&.values&.first
    end

    def count(sql, *params)
      query_value(sql, *params).to_i
    end

    def close
      unless @connection.nil?
        @connection.close
        @connection = nil
      end
    end

    def reset
      close
      connect
      configure_connection
    end

    def escape_string(str)
      @connection.escape(str)
    end

    def encode_array(array)
      "(#{array.map { |v| "'#{escape_string(v.to_s)}'" }.join(",")})"
    end

    private

    def with_reconnect(retries: 3)
      attempts = 0
      begin
        yield
      rescue Mysql2::Error => e
        attempts += 1
        if attempts <= retries && connection_lost?(e)
          reset
          retry
        end
        raise
      end
    end

    def connection_lost?(error)
      error.message.include?("Lost connection") || error.message.include?("server has gone away") ||
        error.message.include?("Can't connect to")
    end

    def connect
      @connection =
        Mysql2::Client.new(
          host: @settings[:host],
          port: @settings[:port] || 3306,
          username: @settings[:username] || @settings[:user],
          password: @settings[:password],
          database: @settings[:database] || @settings[:dbname],
          encoding: @settings[:encoding] || "utf8mb4",
          reconnect: true,
          read_timeout: @settings[:read_timeout] || 3600,
          write_timeout: @settings[:write_timeout] || 3600,
        )
    end

    def configure_connection
      @connection.query("SET NAMES 'utf8mb4'")
      @connection.query("SET SESSION sql_mode = ''")
      @connection.query("SET SESSION wait_timeout = 28800")
      @connection.query("SET SESSION net_read_timeout = 3600")
      @connection.query("SET SESSION net_write_timeout = 3600")
    end

    def interpolate_params(sql, params)
      param_index = 0
      sql.gsub("?") do
        value = params[param_index]
        param_index += 1
        escape_value(value)
      end
    end

    def escape_value(value)
      case value
      when nil
        "NULL"
      when Integer, Float
        value.to_s
      when true
        "1"
      when false
        "0"
      else
        "'#{@connection.escape(value.to_s)}'"
      end
    end
  end
end
