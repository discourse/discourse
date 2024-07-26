# frozen_string_literal: true

require "extralite"
require "lru_redux"

module Migrations::Database
  class Connection
    TRANSACTION_BATCH_SIZE = 1000
    PREPARED_STATEMENT_CACHE_SIZE = 5

    DEFAULT_INSERT_ACTIONS = { "config" => "OR REPLACE", "uploads" => "OR IGNORE" }

    def self.open_database(path:)
      FileUtils.mkdir_p(File.dirname(path))

      db = Extralite::Database.new(path)
      db.pragma(
        busy_timeout: 60_000, # 60 seconds
        journal_mode: "wal",
        synchronous: "off",
        temp_store: "memory",
        locking_mode: "normal",
        cache_size: -10_000, # 10_000 pages
      )
      db
    end

    attr_reader :db
    attr_reader :path

    def initialize(path:, transaction_batch_size: TRANSACTION_BATCH_SIZE)
      @path = path
      @transaction_batch_size = transaction_batch_size
      @db = self.class.open_database(path: path)
      @statement_counter = 0

      # don't cache too many prepared statements
      @statement_cache = PreparedStatementCache.new(PREPARED_STATEMENT_CACHE_SIZE)
    end

    def close
      if @db
        commit_transaction
        @statement_cache.clear
        @db.close
      end

      @db = nil
      @statement_counter = 0
    end

    def reconnect
      close
      @db = self.class.open_database(path: @path)
    end

    def copy_from(source_db_paths, insert_actions: DEFAULT_INSERT_ACTIONS)
      commit_transaction
      @statement_counter = 0

      table_names = @db.tables.excluding("schema_migrations")

      source_db_paths.each do |source_db_path|
        @db.execute("ATTACH DATABASE ? AS source", source_db_path)

        table_names.each do |table_name|
          or_action = insert_actions[table_name] || ""
          @db.execute("INSERT #{or_action} INTO #{table_name} SELECT * FROM source.#{table_name}")
        end

        @db.execute("DETACH DATABASE source")
      end
    end

    def insert(sql, *parameters)
      begin_transaction if @statement_counter == 0

      stmt = @statement_cache.getset(sql) { @db.prepare(sql) }
      stmt.execute(*parameters)

      if (@statement_counter += 1) >= @transaction_batch_size
        commit_transaction
        @statement_counter = 0
      end
    end

    private

    def begin_transaction
      return if @db.transaction_active?

      @db.execute("BEGIN DEFERRED TRANSACTION")
    end

    def commit_transaction
      return unless @db.transaction_active?

      @db.execute("COMMIT")
    end
  end
end
