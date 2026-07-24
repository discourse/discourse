# frozen_string_literal: true

module Migrations
  module Conversion
    # Merges finished steps' shards into the run database on a background thread,
    # off the steps' critical path. A coordinator hands its shards over the
    # moment its workers exit and finishes the step right away, so the step no
    # longer lingers at 100% while its (possibly large) merge runs, and the merge
    # overlaps the steps that come after it.
    #
    # It writes straight to the run DB `Connection` — the only thing that touches
    # it, since steps write to their own shards. That connection closes and
    # reopens around every worker fork (Extralite isn't thread-safe, and a child
    # must not inherit an open handle), so a merge takes `fork_mutex` to serialize
    # against forking: a merge can't run while the connection is closed for a fork,
    # and a fork waits for an in-flight merge.
    class Consolidator
      # @param shard_manager [ShardManager] used to discard each shard once merged
      # @param connection [Database::Connection] the run DB connection merges write to
      # @param fork_mutex [Mutex] serializes merges against worker forks (see above)
      def initialize(shard_manager, connection, fork_mutex)
        @shard_manager = shard_manager
        @connection = connection
        @fork_mutex = fork_mutex
        @queue = Thread::Queue.new
        @errors = []
        @thread = Thread.new { run }
        @thread.name = "consolidator"
      end

      # Hands a finished step's shards over to be merged in the background.
      # @param shards [Array<String>] the shard database paths to merge, then discard
      # @return [void]
      def enqueue(shards)
        @queue << shards
      end

      # Runs a block as the run DB's single writer: takes the same `fork_mutex` a
      # merge does (so it can't overlap a background merge or a worker fork) and
      # points IntermediateDB at the run DB connection for the block. A coordinator
      # uses this to write a step's reduced log entries once its workers finish.
      # @return the block's value
      def with_writer(&block)
        @fork_mutex.synchronize { Database::IntermediateDB.with_connection(@connection, &block) }
      end

      # Waits for every enqueued shard to be merged, then returns the merge errors.
      # @return [Array<StandardError>] the errors from any merge that failed (empty
      #   when all merged cleanly)
      def drain
        @queue.close
        @thread.join
        @errors
      end

      private

      def run
        while (shards = @queue.pop)
          shards.each { |shard_path| merge(shard_path) }
        end
      end

      def merge(shard_path)
        @fork_mutex.synchronize do
          @connection.merge_database(shard_path, tables: mergeable_tables, dedupe_tables:)
        end
      rescue StandardError => e
        @errors << e
      ensure
        @shard_manager.discard(shard_path)
      end

      # `config` and `schema_migrations` are run-level and identical in every
      # shard, so they're left out of the merge.
      def mergeable_tables
        @mergeable_tables ||= @connection.tables - %w[config schema_migrations]
      end

      # The mergeable tables whose model opts into `INSERT OR IGNORE`; the rest
      # raise on a duplicate. Derived from the models, so adding a table needs no
      # change here (see `IntermediateDB.conflict_strategy_for`).
      def dedupe_tables
        @dedupe_tables ||=
          mergeable_tables.select do |table|
            Database::IntermediateDB.conflict_strategy_for(table) == :ignore
          end
      end
    end
  end
end
