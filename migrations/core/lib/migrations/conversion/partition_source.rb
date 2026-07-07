# frozen_string_literal: true

module Migrations
  module Conversion
    # The interface a source DB adapter implements so a step can `partition_by`.
    # An adapter includes this module to declare it, and must provide:
    #
    #   partition_bounds(key, from, base)      -> [min, max]
    #   estimated_row_count(from)              -> Integer  (planner row estimate)
    #   count_all(from, where:)                -> Integer  (exact row count)
    #   chunk_filter(key, lower, upper, base:) -> the SQL WHERE body for one chunk
    #
    # plus one way to read the sorted key — either the fast, in-SQL
    #
    #   boundaries_by_scan(key, from, base, count) -> the chunk lower bounds
    #
    # or the streaming fallback the {Partitioner} samples itself:
    #
    #   each_partition_key(key, from, base)    -> yields each key value, in order
    #
    # The Partitioner checks a source against this in the parent before forking, so
    # a source that can't partition fails fast with a clear error instead of
    # crashing a worker with a bare NoMethodError.
    module PartitionSource
      REQUIRED = %i[partition_bounds estimated_row_count count_all chunk_filter].freeze
      SCAN = %i[boundaries_by_scan each_partition_key].freeze # at least one

      # The interface methods `source` doesn't provide (empty when it satisfies the
      # contract).
      def self.missing_from(source)
        missing = REQUIRED.reject { |method| source.respond_to?(method) }
        missing << SCAN.join(" or ") if SCAN.none? { |method| source.respond_to?(method) }
        missing
      end
    end
  end
end
