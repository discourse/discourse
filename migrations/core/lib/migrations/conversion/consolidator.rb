# frozen_string_literal: true

module Migrations
  module Conversion
    # Merges finished steps' shards into the run database on a background thread,
    # off the steps' critical path. A coordinator hands its shards over the
    # moment its workers exit and finishes the step right away, so the step no
    # longer lingers at 100% while its (possibly large) merge runs, and the merge
    # overlaps the steps that come after it.
    #
    # `merge_shard` takes the run-level writer's mutex per shard, so the
    # background merges interleave with the fork windows of later steps rather
    # than blocking them for a whole step's worth of shards at once.
    class Consolidator
      def initialize(shard_manager)
        @shard_manager = shard_manager
        @queue = Thread::Queue.new
        @errors = []
        @thread = Thread.new { run }
        @thread.name = "consolidator"
      end

      def enqueue(shards)
        @queue << shards
      end

      # Waits for every enqueued shard to be merged, then returns the merge errors.
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
        Database::IntermediateDB.merge_shard(shard_path)
      rescue StandardError => e
        @errors << e
      ensure
        @shard_manager.discard(shard_path)
      end
    end
  end
end
