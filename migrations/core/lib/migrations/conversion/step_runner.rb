# frozen_string_literal: true

module Migrations
  module Conversion
    # Runs one step's items to completion inside a single process. The worker
    # opens its own source, so the read happens here in the fork, not in the
    # parent, then reads the rows it is responsible for, processes each, and
    # writes them to its shard. Nothing is sent in but the step to run, and
    # nothing goes back but progress.
    #
    # The insert runs here against a real connection, so a bad row (a NULL in a
    # NOT NULL column, say) raises right where it's processed, to be logged and
    # skipped per item rather than failing the whole step.
    class StepRunner
      # How many processed items to accumulate before reporting progress.
      REPORT_INTERVAL = 1_000

      # @param step [Step] the step to run; its source and processor are built here
      # @param shard_path [String] the SQLite shard this worker writes its rows to
      # @param reporter [#report_max_progress, #report_progress] the worker's end of
      #   the progress channel ({PipeProgressSink} in a fork, {InlineProgressSink} inline)
      # @param chunk [Array(Object, Object), nil] the `[lower, upper]` key range to read
      #   (upper nil = open-ended), or nil to read the whole source
      # @param chunks [#call, nil] for work stealing: call it to get the next
      #   `[lower, upper]` to read, or nil when none are left. When given, the worker
      #   keeps claiming chunks into its one shard and the parent owns the total.
      #   Replaces `chunk`.
      def initialize(step:, shard_path:, reporter:, chunk: nil, chunks: nil)
        @step = step
        @shard_path = shard_path
        @reporter = reporter
        @chunk = chunk
        @chunks = chunks
      end

      def run
        source = @step.source
        connection = Database::Connection.new(path: @shard_path)

        begin
          # Point IntermediateDB at this worker's shard for the block.
          # `with_connection` restores the previous connection afterwards without
          # closing it — unlike `setup`, which closes it; under `--no-fork` that
          # previous connection is the live run DB connection the rest of the
          # run still needs.
          Database::IntermediateDB.with_connection(connection) do
            processor = @step.create_processor
            SetupGuard.run(processor)

            @chunks ? run_claimed_chunks(source, processor) : run_chunk(source, processor)
          end
        ensure
          connection.close
          source.cleanup
        end
      end

      private

      # One slice, or the whole source: the worker reports its own total.
      def run_chunk(source, processor)
        source.chunk = @chunk
        @reporter.report_max_progress(source.max_progress)
        process_items(source, processor)
      end

      # Work stealing: claim chunks until the bag is empty, all into one shard. The
      # parent knows the total, so we don't report it here.
      def run_claimed_chunks(source, processor)
        while (chunk = @chunks.call)
          source.chunk = chunk
          process_items(source, processor)
        end
      end

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
