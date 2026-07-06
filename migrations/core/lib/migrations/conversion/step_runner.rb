# frozen_string_literal: true

module Migrations
  module Conversion
    # Runs one step's items inside a single process. The worker opens its own
    # source, claims chunks of it to read, processes each row, and writes them to
    # its shard. Nothing goes in but the step to run and a way to claim chunks, and
    # nothing comes back but progress.
    #
    # The insert runs here on a real connection, so a bad row (a NULL in a NOT NULL
    # column, say) raises where it's processed, to be logged and skipped instead of
    # failing the whole step.
    class StepRunner
      # How many processed items to accumulate before reporting progress.
      REPORT_INTERVAL = 1_000

      # The whole source: one chunk, open at both ends. The default when no chunks
      # are given.
      WHOLE_SOURCE = [[nil, nil]].freeze

      # The parent owns the step's total, so no worker reports its own here; it just
      # reads the chunks it's handed and reports progress.
      #
      # @param step [Step] the step to run; its source and processor are built here
      # @param shard_path [String] the SQLite shard this worker writes its rows to
      # @param reporter [#report_progress] the worker's end of the progress channel
      #   ({PipeProgressSink} in a fork, {InlineProgressSink} inline)
      # @param chunks [#each] the chunks to read, one at a time: each a `[lower,
      #   upper]` key range, where a nil bound is open — so `[nil, nil]` is the whole
      #   source. Defaults to the whole source; a work-stealing worker passes a lazy
      #   enumerator that hands back the next chunk off the shared queue each time
      #   round.
      def initialize(step:, shard_path:, reporter:, chunks: WHOLE_SOURCE)
        @step = step
        @shard_path = shard_path
        @reporter = reporter
        @chunks = chunks
      end

      def run
        source = @step.source
        connection = Database::Connection.new(path: @shard_path)

        begin
          # Point IntermediateDB at this worker's shard for the block.
          # `with_connection` restores the previous connection afterwards without
          # closing it, unlike `setup`, which closes it; under `--no-fork` that
          # previous connection is the live run DB connection the rest of the run
          # still needs.
          Database::IntermediateDB.with_connection(connection) do
            processor = @step.create_processor
            SetupGuard.run(processor)

            @chunks.each do |chunk|
              source.chunk = chunk
              process_items(source, processor)
            end
          end
        ensure
          connection.close
          source.cleanup
        end
      end

      private

      def process_items(source, processor)
        tracker = processor.tracker
        progress = warnings = errors = 0

        source.items.each do |item|
          tracker.reset_stats!

          begin
            processor.process(item)
          rescue StandardError => e
            tracker.log_error("Failed to process item", exception: e, details: item)
          end

          stats = tracker.stats
          progress += stats.progress
          warnings += stats.warning_count
          errors += stats.error_count

          next if progress < REPORT_INTERVAL
          @reporter.report_progress(progress:, warnings:, errors:)
          progress = warnings = errors = 0
        end

        return if progress.zero? && warnings.zero? && errors.zero?
        @reporter.report_progress(progress:, warnings:, errors:)
      end
    end
  end
end
