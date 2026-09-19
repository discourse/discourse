# frozen_string_literal: true

module Migrations
  module Conversion
    # Works out how to split a partitioned step's source into `count` chunks. All
    # the logic here is dialect-free; the dialect-specific SQL lives in the source
    # DB adapter, which this calls through a couple of primitives:
    #
    #   count_all(from, where:)              -> Integer (exact)
    #   each_partition_key(key, from, base)  -> yields each key value, sorted
    #
    # It always samples the sorted key, so the chunks hold about the same number of
    # rows whatever the key is. Cutting a numeric key into equal ranges by value
    # would be cheaper, but that only works with about one row per value. A foreign
    # key like `topic_id`, where a busy topic has many rows and a quiet one few,
    # would give very uneven chunks, so we don't do it; the scan is worth the even
    # split.
    #
    # The sampling streams the whole key column here and picks every Nth value. An
    # adapter that can do better in SQL (e.g. Postgres with `NTILE`) may add an
    # optional primitive and skip the streaming:
    #
    #   boundaries_by_scan(key, from, base, count) -> the chunk lower bounds
    #
    # When it's there we use it; otherwise we fall back to streaming, so a new
    # adapter gets a working partitioner from the two primitives alone.
    class Partitioner
      # Raised when a step declares `partition_by` but its source can't compute
      # boundaries: the adapter is missing partition primitives, or there is no
      # source DB at all (e.g. a file source).
      class UnsupportedSourceError < StandardError
      end

      # @param source_db [Object] the source DB adapter providing the primitives above
      # @param key [Symbol, String, Array<Symbol>] the partition key: one column, or
      #   an array of columns for a composite key
      # @param from [String] the table (or other source name) to split
      # @param base [String, nil] a SQL filter that always applies, or nil for none
      def initialize(source_db, key:, from:, base:)
        @source_db = source_db
        @key = key
        @from = from
        @base = base
      end

      # @param count [Integer] how many chunks to split the source into
      # @return [Array] the `count` chunk lower bounds; chunk i covers
      #   `[bounds[i], bounds[i + 1])`, the last open-ended. Empty for an empty source.
      # @raise [UnsupportedSourceError] if the source can't compute boundaries
      def boundaries(count)
        ensure_source_can_partition!
        scan_boundaries(count)
      end

      private

      def ensure_source_can_partition!
        missing = PartitionSource.missing_from(@source_db)
        return if missing.empty?

        raise UnsupportedSourceError,
              "Can't partition `#{@from}`: its source doesn't implement the " \
                "PartitionSource interface (missing #{missing.join(", ")}). " \
                "Implement it, or remove `partition_by` from the step."
      end

      def scan_boundaries(count)
        if @source_db.respond_to?(:boundaries_by_scan)
          @source_db.boundaries_by_scan(@key, @from, @base, count)
        else
          sampled_boundaries(count)
        end
      end

      def sampled_boundaries(count)
        total = @source_db.count_all(@from, where: @base)
        return [] if total.zero?

        sample_every = [(total.to_f / count).ceil, 1].max
        boundaries = []
        index = 0
        @source_db.each_partition_key(@key, @from, @base) do |value|
          boundaries << value if (index % sample_every).zero? && boundaries.size < count
          index += 1
        end
        boundaries
      end
    end
  end
end
