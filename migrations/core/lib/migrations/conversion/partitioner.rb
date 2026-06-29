# frozen_string_literal: true

module Migrations
  module Conversion
    # Works out how to split a partitioned step's source into `count` chunks. All
    # the logic here is dialect-free; the dialect-specific SQL lives in the source
    # DB adapter, which this calls through a few primitives:
    #
    #   partition_bounds(key, from, base)    -> [min, max]
    #   estimated_row_count(from)            -> Integer (the planner's estimate)
    #   count_all(from, where:)              -> Integer (exact)
    #   each_partition_key(key, from, base)  -> yields each key value, sorted
    #
    # A dense numeric key strides evenly by value, which is cheap. A sparse one
    # (big gaps from deletes, or ids from a shared sequence), or any non-numeric or
    # composite key, is sampled from the sorted key instead, so the chunks hold
    # even row counts whatever the distribution.
    #
    # The sampling streams the whole key column here and picks every Nth value. An
    # adapter that can do better in SQL (e.g. Postgres with `NTILE`) may add an
    # optional primitive and skip the streaming:
    #
    #   boundaries_by_scan(key, from, base, count) -> the chunk lower bounds
    #
    # When it's there we use it; otherwise we fall back to streaming, so a new
    # adapter gets a working partitioner from the four primitives alone.
    class Partitioner
      # Raised when a step declares `partition_by` but its source can't compute
      # boundaries — the adapter is missing partition primitives (or there is no
      # source DB at all, e.g. a file source).
      class UnsupportedSourceError < StandardError
      end

      # How much wider a numeric key's value range may run than its row count
      # before even value-sized chunks stop holding even row counts. Past this, the
      # gaps leave some chunks nearly empty, so we sample the sorted key instead.
      DENSE_RANGE_FACTOR = 4

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
        return scan_boundaries(count) if @key.is_a?(Array)

        min, max = @source_db.partition_bounds(@key, @from, @base)
        return [] if min.nil?
        return numeric_boundaries(min, max, count) if min.is_a?(Numeric) && dense?(min, max)

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

      def dense?(min, max)
        rows = @source_db.estimated_row_count(@from)
        # No usable estimate (an adapter returns 0 or less when it can't estimate
        # the row count): don't pay for a full key scan on a guess — default to the
        # cheap value stride.
        return true if rows <= 0
        (max - min + 1) <= rows * DENSE_RANGE_FACTOR
      end

      def numeric_boundaries(min, max, count)
        chunk_size = ((max - min + 1).to_f / count).ceil
        Array.new(count) { |i| min + i * chunk_size }.uniq
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
