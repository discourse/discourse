# frozen_string_literal: true

require "fileutils"

module Migrations
  module Conversion
    # Hands out per-worker shard databases for the sharded write path. A shard is
    # a private copy of an empty database with the run's schema, so a worker opens
    # it and runs the exact same inserts it would against the run database, just
    # without touching the single run-level connection that is the throughput
    # ceiling. Once a step's workers are done the coordinator merges their shards
    # into the run database (see {Consolidator}) and discards
    # them.
    #
    # The template is a fresh, empty database migrated from the same schema as the
    # run DB — not a copy of the run DB. That keeps a shard cheap to copy, and —
    # importantly — means a run against an existing IntermediateDB doesn't drag the
    # existing rows into every shard; the merge just adds each shard's new rows
    # with `INSERT OR IGNORE`.
    class ShardManager
      # @param canonical_path [String] the run's IntermediateDB; the shards and
      #   their template are placed next to it
      # @param migrations_path [String] the schema migrations, used to build the
      #   empty template
      def initialize(canonical_path:, migrations_path:)
        @dir = File.join(File.dirname(canonical_path), "shards")
        FileUtils.mkdir_p(@dir)

        @template_path = File.join(@dir, "template.db")
        Database.delete_database(@template_path)
        Database.migrate(@template_path, migrations_path:)

        @counter = 0
        @mutex = Mutex.new
      end

      # @return [String] the path of a fresh shard, copied from the template
      def create_shard
        index = @mutex.synchronize { @counter += 1 }
        path = File.join(@dir, "shard-#{index}.db")
        FileUtils.cp(@template_path, path)
        path
      end

      # Removes a shard and its WAL/SHM sidecar files.
      # @param path [String] the shard database path returned by {#create_shard}
      # @return [void]
      def discard(path)
        Database.delete_database(path)
      end

      def cleanup
        FileUtils.rm_rf(@dir)
      end
    end
  end
end
