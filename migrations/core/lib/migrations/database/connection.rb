# frozen_string_literal: true

module Migrations
  module Database
    class Connection
      TRANSACTION_BATCH_SIZE = 1000
      PREPARED_STATEMENT_CACHE_SIZE = 32

      # Only the parent's reopenable database can be suspended during an insert.
      # Worker shards forbid forks, so their hot path needs no per-row dispatch.
      module ReopenableInserts
        def insert(sql, parameters = [])
          @connection.with { super }
        end
      end
      private_constant :ReopenableInserts

      def self.open_database(**options)
        new(**options)
      end

      attr_reader :path

      def initialize(
        path:,
        journal_mode: "wal",
        transaction_batch_size: TRANSACTION_BATCH_SIZE,
        reopenable: false
      )
        extend ReopenableInserts if reopenable
        @path = File.expand_path(path, Migrations.root_path)
        @transaction_batch_size = transaction_batch_size
        @statement_counter = 0
        @statement_cache = PreparedStatementCache.new(PREPARED_STATEMENT_CACHE_SIZE)
        @connection =
          ManagedConnection.open(
            Drivers::Sqlite.new(
              path: @path,
              journal_mode:,
              reopenable:,
              statement_cache: @statement_cache,
            ),
          )
      end

      def close
        if closed?
          @connection.close
          @path = nil
          return
        end
        Lifecycle.synchronize do
          commit_transaction
          @connection.close
          @path = nil
        end
      end

      def closed?
        @connection.closed?
      end

      def insert(sql, parameters = [])
        begin_transaction if @statement_counter == 0
        stmt = @statement_cache.getset(sql) { @connection.with { |db| db.prepare(sql) } }
        stmt.execute(parameters)
        commit_transaction if (@statement_counter += 1) >= @transaction_batch_size
        nil
      end

      def query(sql, *parameters, **named_parameters, &block)
        @connection.with { |db| db.query(sql, *parameters, **named_parameters, &block) }
      end

      def query_array(sql, *parameters, &block)
        @connection.with { |db| db.query_array(sql, *parameters, &block) }
      end

      def query_splat(sql, *parameters, &block)
        @connection.with { |db| db.query_splat(sql, *parameters, &block) }
      end

      def query_value(sql, *parameters)
        @connection.with { |db| db.query_single_splat(sql, *parameters) }
      end
      alias query_single_splat query_value

      def count(sql)
        query_value(sql).to_i
      end

      def tables
        @connection.with(&:tables)
      end

      def execute(sql, *parameters, **named_parameters)
        @connection.with { |db| db.execute(sql, *parameters, **named_parameters) }
      end

      def pragma(*args, **kwargs)
        @connection.with { |db| db.pragma(*args, **kwargs) }
      end

      def transaction_active?
        @connection.with(&:transaction_active?)
      end

      def transaction
        @connection.with { |db| db.transaction { yield self } }
      end

      # ATTACH cannot run in the wrapper's batched insert transaction.
      def attach_database(path, name:)
        @connection.with do |db|
          commit_transaction
          db.execute("ATTACH DATABASE ? AS #{quote_identifier(name)}", path)
        end
      end

      def merge_database(other_path, tables:, dedupe_tables: [])
        @connection.with do |db|
          attach_database(other_path, name: "merge_source")
          begin
            tables.each do |table|
              quoted = quote_identifier(table)
              conflict_clause = dedupe_tables.include?(table) ? "OR IGNORE " : ""
              db.execute(
                "INSERT #{conflict_clause}INTO main.#{quoted} SELECT * FROM merge_source.#{quoted}",
              )
            rescue Extralite::Error => error
              raise "Failed to merge table #{table.inspect}: #{error.message}"
            end
          ensure
            db.execute("DETACH DATABASE merge_source")
          end
        end
        nil
      end

      def begin_transaction
        @connection.with do |db|
          db.execute("BEGIN DEFERRED TRANSACTION") unless db.transaction_active?
        end
      end

      def commit_transaction
        @connection.with do |db|
          if db.transaction_active?
            db.execute("COMMIT")
            @statement_counter = 0
          end
        end
      end

      private

      def quote_identifier(name)
        %("#{name.gsub('"', '""')}")
      end
    end
  end
end
