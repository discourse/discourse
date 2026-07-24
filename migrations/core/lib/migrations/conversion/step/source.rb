# frozen_string_literal: true

module Migrations
  module Conversion
    class Step
      class Source
        include AttributeAssignment

        # `source_db` is the step's own connection to the source data, when it has
        # one. Steps that read from somewhere else (a file, fixed data) leave it
        # nil. The converter injects it through `step_args`.
        attr_accessor :settings, :source_db

        # The `[lower, upper]` key range this worker reads (`upper` nil means
        # open-ended), or nil for an unpartitioned step. The runner sets it before
        # `items`; the generated queries (and `partition_slice`) apply it.
        attr_accessor :chunk

        class << self
          # Read a whole table: defines `items` (`SELECT * FROM <name>`) and
          # `max_progress` (its row count), both filtered by `where`. Works with
          # or without `partition_by` (a partitioned step also limits each query
          # to its chunk). Override `items`/`max_progress` for anything custom.
          #
          # `order` (a column or array of them) sorts the read — worth setting for
          # a large table whose rows insert faster in that order (it should match
          # the target's key, and be indexed at the source so it doesn't add a
          # sort). A partitioned step ignores it and orders by its key instead.
          def reads_table(name, where: nil, order: nil)
            @table = { name:, where:, order: }
          end

          attr_reader :table

          def reads_table?
            !table.nil?
          end

          # Split the step across forks on `key` (one column, or an array of
          # columns for a composite key). `from`/`base` say which table and filter
          # to scan for the boundaries; they default to the `reads_table` ones, so
          # a table-reading step only needs the key.
          def partition_by(key, from: nil, base: nil)
            @partition = { key:, from:, base: }
          end

          attr_reader :partition

          def partitionable?
            !partition.nil?
          end
        end

        def initialize(args = {})
          assign_attributes(args)
        end

        # The chunk boundaries for splitting the source `count` ways, worked out
        # in the parent before forking.
        def partition_boundaries(count)
          Partitioner.new(
            @source_db,
            key: partition_key,
            from: partition_from,
            base: partition_base,
          ).boundaries(count)
        end

        # The WHERE body that limits a query to this worker's chunk. Add it to a
        # custom query (`WHERE #{partition_slice}`); the generated queries already
        # use it.
        def partition_slice
          lower, upper = chunk
          @source_db.chunk_filter(partition_key, lower, upper, base: partition_base)
        end

        def max_progress
          return unless self.class.reads_table?
          @source_db.count_all(self.class.table[:name], where: read_filter)
        end

        def items
          raise NotImplementedError unless self.class.reads_table?
          @source_db.select_all(self.class.table[:name], where: read_filter, order: read_order)
        end

        def cleanup
          @source_db&.close
        end

        private

        # The rows the current read should see: this worker's chunk when
        # partitioned, otherwise the whole table's filter.
        def read_filter
          self.class.partitionable? ? partition_slice : self.class.table[:where]
        end

        # A partitioned read is ordered by its key so each worker writes its shard
        # in key order (sequential index inserts, in the shard and in the merge).
        # An unpartitioned read uses `reads_table`'s `order`, if any.
        def read_order
          return partition_key if self.class.partitionable?
          self.class.table[:order]
        end

        def partition_key
          self.class.partition[:key]
        end

        def partition_from
          self.class.partition[:from] || self.class.table&.fetch(:name)
        end

        def partition_base
          self.class.partition[:base] || self.class.table&.fetch(:where)
        end
      end
    end
  end
end
