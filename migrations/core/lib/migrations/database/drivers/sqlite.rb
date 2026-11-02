# frozen_string_literal: true

require "extralite"
require "fileutils"

module Migrations
  module Database
    module Drivers
      # Reopenable SQLite connections are closed while workers are forked.
      class Sqlite
        # @param path [String] the database file; missing parent directories are
        #   created on open
        # @param journal_mode [String] the SQLite journal mode
        # @param reopenable [Boolean] close and reopen the database around forks
        # @param statement_cache [PreparedStatementCache, nil] cleared on close,
        #   because its statements belong to the closed handle
        def initialize(path:, journal_mode: "wal", reopenable: false, statement_cache: nil)
          @path = path
          @journal_mode = journal_mode
          @reopenable = reopenable
          @statement_cache = statement_cache
        end

        def fork_policy
          @reopenable ? :reopen : :forbid_fork
        end

        def open
          FileUtils.mkdir_p(File.dirname(@path))
          Extralite::Database.new(@path, stmt_cache: false)
        end

        def configure(connection)
          connection.pragma(
            busy_timeout: 60_000,
            journal_mode: @journal_mode,
            synchronous: "off",
            temp_store: "memory",
            locking_mode: "normal",
            cache_size: -10_000,
          )
        end

        def validate_fork!(connection)
          if connection.transaction_active? || attached_database?(connection) ||
               temporary_schema?(connection)
            raise Lifecycle::UnsafeForkError,
                  "SQLite has an active transaction, attached database, or temporary schema; cannot reopen it safely"
          end
        end

        def close(connection)
          @statement_cache&.clear
          connection.close unless connection.closed?
        end

        private

        def attached_database?(connection)
          connection.query_single_splat(<<~SQL) > 0
            SELECT COUNT(*)
            FROM pragma_database_list
            WHERE name NOT IN ('main', 'temp')
          SQL
        end

        def temporary_schema?(connection)
          connection.query_single_splat(<<~SQL) > 0
            SELECT COUNT(*)
            FROM sqlite_temp_master
          SQL
        end
      end
    end
  end
end
