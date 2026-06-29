# frozen_string_literal: true

module Migrations
  module Conversion
    # Merges finished steps' shards into the run database on a background thread,
    # off the steps' critical path. A coordinator hands its shards over the
    # moment its workers exit and finishes the step right away, so the step no
    # longer lingers at 100% while its (possibly large) merge runs, and the merge
    # overlaps the steps that come after it.
    #
    # It merges through the run-level `DbWriter` directly (not the process-global
    # `IntermediateDB` connection): under `--no-fork` an inline step swaps that
    # global to its own shard connection, and a background merge routed through it
    # would hit the wrong connection. `merge_shard` takes the writer's mutex per
    # shard, so the merges interleave with the fork windows of later steps rather
    # than blocking them for a whole step's worth of shards at once.
    class Consolidator
      # @param shard_manager [ShardManager] used to discard each shard once merged
      # @param writer [Database::DbWriter] the run-level writer merges go through
      def initialize(shard_manager, writer)
        @shard_manager = shard_manager
        @writer = writer
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
        @writer.merge_shard(shard_path)
      rescue StandardError => e
        @errors << e
      ensure
        @shard_manager.discard(shard_path)
      end
    end
  end
end
