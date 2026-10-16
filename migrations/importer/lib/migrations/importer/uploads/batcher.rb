# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # Accumulates items and hands them to a queue in arrays instead of one at a
      # time. A per-row handoff through a SizedQueue costs 2-8x throughput in this
      # subsystem, so both directions of the pipeline move whole batches. Not
      # thread-safe: each producer/worker owns its own batcher.
      class Batcher
        def initialize(queue, batch_size)
          @queue = queue
          @batch_size = batch_size
          @buffer = []
        end

        # Adds one item, flushing a full batch onto the queue. Pushing to a
        # SizedQueue blocks when it is full, which is the backpressure we want.
        def push(item)
          @buffer << item
          flush if @buffer.size >= @batch_size
        end

        # Sends whatever is buffered, even a partial batch. Called when the source
        # is exhausted or the run is winding down.
        def flush
          return if @buffer.empty?

          @queue << @buffer
          @buffer = []
        end
      end
    end
  end
end
