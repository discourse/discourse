# frozen_string_literal: true

require "extralite"
require "lru_redux"

module Migrations
  class IntermediateDb
    DEFAULT_JOURNAL_MODE = "wal"
    TRANSACTION_BATCH_SIZE = 1000
    PREPARED_STATEMENT_CACHE_SIZE = 5

    def self.create_connection(path:, journal_mode: DEFAULT_JOURNAL_MODE)
      db = ::Extralite::Database.new(path)
      db.pragma(
        busy_timeout: 60_000, # 60 seconds
        journal_mode: journal_mode,
        synchronous: "off",
        temp_store: "memory",
        locking_mode: journal_mode == "wal" ? "normal" : "exclusive",
        cache_size: -10_000, # 10_000 pages
      )
      db
    end

    def self.connect
      db = self.class.new
      yield(db)
    ensure
      db.close if db
    end

    attr_reader :connection
    attr_reader :path

    def initialize(path:, journal_mode: DEFAULT_JOURNAL_MODE)
      @path = path
      @journal_mode = journal_mode
      @connection = self.class.create_connection(path: path, journal_mode: journal_mode)
      @statement_counter = 0

      # don't cache too many prepared statements
      @statement_cache = PreparedStatementCache.new(PREPARED_STATEMENT_CACHE_SIZE)
    end

    def close
      if @connection
        commit_transaction
        @statement_cache.clear
        @connection.close
      end

      @connection = nil
      @statement_counter = 0
    end

    def reconnect
      close
      @connection = self.class.create_connection(path: @path, journal_mode: @journal_mode)
    end

    def copy_from(source_db_paths)
      commit_transaction
      @statement_counter = 0

      table_names = get_table_names
      insert_actions = { "config" => "OR REPLACE", "uploads" => "OR IGNORE" }

      source_db_paths.each do |source_db_path|
        @connection.execute("ATTACH DATABASE ? AS source", source_db_path)

        table_names.each do |table_name|
          or_action = insert_actions[table_name] || ""
          @connection.execute(
            "INSERT #{or_action} INTO #{table_name} SELECT * FROM source.#{table_name}",
          )
        end

        @connection.execute("DETACH DATABASE source")
      end
    end

    def begin_transaction
      return if @connection.transaction_active?
      @connection.execute("BEGIN DEFERRED TRANSACTION")
    end

    def commit_transaction
      return unless @connection.transaction_active?
      @connection.execute("COMMIT")
    end

    private

    def insert(sql, *parameters)
      begin_transaction if @statement_counter == 0

      stmt = @statement_cache.getset(sql) { @connection.prepare(sql) }
      stmt.execute(*parameters)

      if (@statement_counter += 1) > TRANSACTION_BATCH_SIZE
        commit_transaction
        @statement_counter = 0
      end
    end

    def iso8601(column_name, alias_name = nil)
      alias_name ||= column_name.split(".").last
      "strftime('%Y-%m-%dT%H:%M:%SZ', #{column_name}) AS #{alias_name}"
    end

    def get_table_names
      @connection.query_splat(<<~SQL)
        SELECT name
          FROM sqlite_schema
         WHERE type = 'table'
           AND name NOT LIKE 'sqlite_%'
           AND name NOT IN ('schema_migrations', 'config')
      SQL
    end
  end
end
