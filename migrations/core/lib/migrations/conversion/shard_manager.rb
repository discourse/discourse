# frozen_string_literal: true

require "fileutils"

module Migrations
  module Conversion
    # Hands out per-worker shard databases for the sharded write path. A shard is
    # a private copy of the empty, migrated IntermediateDB, so a worker opens it
    # and runs the exact same inserts it would against the run database, just
    # without touching the single run-level connection that is the throughput
    # ceiling. Once a step's workers are done the coordinator merges their shards
    # into the run database (see {Database::DbWriter#merge_shard}) and discards
    # them.
    #
    # Copying a prebuilt template file is what makes a shard cheap (a few tenths
    # of a millisecond); running the migrations per worker would not be.
    class ShardManager
      def initialize(canonical_path:)
        @dir = File.join(File.dirname(canonical_path), "shards")
        FileUtils.mkdir_p(@dir)

        @template_path = File.join(@dir, "template.db")
        FileUtils.cp(canonical_path, @template_path)

        @counter = 0
        @mutex = Mutex.new
      end

      def create_shard
        index = @mutex.synchronize { @counter += 1 }
        path = File.join(@dir, "shard-#{index}.db")
        FileUtils.cp(@template_path, path)
        path
      end

      def discard(path)
        [path, "#{path}-wal", "#{path}-shm"].each { |file| File.delete(file) if File.exist?(file) }
      end

      def cleanup
        FileUtils.rm_rf(@dir)
      end
    end
  end
end
