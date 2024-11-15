# frozen_string_literal: true

require "extralite"

module Migrations::Database
  class Connection
    TRANSACTION_BATCH_SIZE = 1000
    PREPARED_STATEMENT_CACHE_SIZE = 5

    def self.open_database(path:)
      FileUtils.mkdir_p(File.dirname(path))

      db = ::Extralite::Database.new(path)
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

    attr_reader :db, :path

    def initialize(path:, transaction_batch_size: TRANSACTION_BATCH_SIZE)
      @path = path
      @transaction_batch_size = transaction_batch_size
      @db = self.class.open_database(path:)
      @statement_counter = 0
      @statement_cache = PreparedStatementCache.new(PREPARED_STATEMENT_CACHE_SIZE)

      @fork_hooks = setup_fork_handling
    end

    def close
      close_connection(keep_path: false)

      before_hook, after_hook = @fork_hooks
      ::Migrations::ForkManager.remove_before_fork_hook(before_hook)
      ::Migrations::ForkManager.remove_after_fork_parent_hook(after_hook)
    end

    def closed?
      @db.nil? || @db.closed?
    end

    def insert(sql, parameters = [])
      begin_transaction if @statement_counter == 0

      stmt = @statement_cache.getset(sql) { @db.prepare(sql) }
      stmt.execute(parameters)

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

    def close_connection(keep_path:)
      return if @db.nil?

      commit_transaction
      @statement_cache.clear
      @db.close

      @path = nil unless keep_path
      @db = nil
      @statement_counter = 0
    end

    def setup_fork_handling
      before_hook = ::Migrations::ForkManager.before_fork { close_connection(keep_path: true) }

      after_hook =
        ::Migrations::ForkManager.after_fork_parent do
          @db = self.class.open_database(path: @path) if @path
        end

      [before_hook, after_hook]
    end
  end
end
