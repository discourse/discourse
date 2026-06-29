# frozen_string_literal: true

module Migrations
  module Database
    # Owns the `Connection` of the IntermediateDB for a whole conversion run and
    # writes to it directly on the caller's thread. There is no writer thread and
    # no queue.
    #
    # Steps don't write their rows through here row by row: each worker writes to
    # its own shard database and the coordinator folds the finished shards back
    # in through `merge_shard`. What still goes through the one connection is the
    # merges themselves, plus any direct `insert` (run-level config, say). All of
    # it touches a shared `Connection`, which isn't thread-safe (a statement
    # counter, the prepared-statement cache, an open batched transaction), so a
    # single mutex serializes it.
    #
    # A failing insert raises to its own caller and nothing more, the writer
    # stays usable. The connection is shared by every step, so storing the error
    # and failing later inserts (as a single-producer writer could) would let one
    # step's bad row take down every other step running at the time.
    #
    # `insert`, `merge_shard` and `close` are no-ops in forked child processes
    # (workers write to their shard through a `Connection` of their own), so the
    # worker's `IntermediateDB.setup` swap can't reach the inherited connection.
    class DbWriter
      class ClosedError < StandardError
      end

      def initialize(path:)
        @owner_pid = Process.pid
        @mutex = Mutex.new
        @closed = false

        # Registration order matters: the lock must be taken before the connection
        # closes and released after it reopens. `ForkManager` runs hooks in
        # registration order, so register the lock hook before `Connection.new`
        # registers the connection's hooks, and the unlock hook after.
        @before_fork_hook = ForkManager.before_fork { @mutex.lock }
        begin
          @connection = Connection.new(path:)
          @after_fork_hook = ForkManager.after_fork_parent { @mutex.unlock }
        rescue StandardError
          ForkManager.remove_before_fork(@before_fork_hook)
          raise
        end
      end

      def insert(sql, parameters = [])
        return if Process.pid != @owner_pid

        @mutex.synchronize do
          check_open!
          @connection.insert(sql, parameters)
        end

        nil
      end

      def merge_shard(path)
        return if Process.pid != @owner_pid

        @mutex.synchronize do
          check_open!
          @connection.merge_database(path, tables: mergeable_tables)
        end

        nil
      end

      def close
        return if Process.pid != @owner_pid

        @mutex.synchronize do
          return if @closed
          @closed = true
          @connection.close
          ForkManager.remove_before_fork(@before_fork_hook)
          ForkManager.remove_after_fork_parent(@after_fork_hook)
        end

        nil
      end

      def closed?
        return true if Process.pid != @owner_pid
        @mutex.synchronize { @closed }
      end

      private

      # `config` and `schema_migrations` are run-level and identical in every
      # shard, so they're left out of the merge.
      def mergeable_tables
        @mergeable_tables ||= @connection.tables - %w[config schema_migrations]
      end

      def check_open!
        raise ClosedError, "`DbWriter` is closed" if @closed
      end
    end
  end
end
