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

      MAX_LOGGED_STRING_LENGTH = 5_000

      # The whole source: one chunk, open at both ends. The default when no chunks
      # are given.
      WHOLE_SOURCE = [[nil, nil]].freeze

      # The parent owns the step's total, so no worker reports its own here; it just
      # reads the chunks it's handed and reports progress.
      #
      # @param step [Step] the step to run; its source and processor are built here
      # @param shard_path [String] the SQLite shard this worker writes its rows to
      # @param channel [#report_progress] the worker's end of the progress channel
      #   ({PipeProgressChannel} in a fork, {InlineProgressChannel} inline)
      # @param chunks [#each] the chunks to read, one at a time: each a `[lower,
      #   upper]` key range, where a nil bound is open — so `[nil, nil]` is the whole
      #   source. Defaults to the whole source; a work-stealing worker passes a lazy
      #   enumerator that hands back the next chunk off the shared queue each time
      #   round.
      def initialize(step:, shard_path:, channel:, chunks: WHOLE_SOURCE)
        @step = step
        @shard_path = shard_path
        @channel = channel
        @chunks = chunks
      end

      def run
        source = @step.source
        # A shard is single-writer, thrown away on failure, and read only once (in
        # full) at merge, so it skips WAL entirely.
        connection = Database::Connection.new(path: @shard_path, journal_mode: "off")

        begin
          # Point IntermediateDB at this worker's shard for the block.
          # `with_connection` restores the previous connection afterwards without
          # closing it, unlike `setup`, which closes it; under `--no-fork` that
          # previous connection is the live run DB connection the rest of the run
          # still needs.
          Database::IntermediateDB.with_connection(connection) do
            processor = @step.create_processor
            begin
              SetupGuard.run(processor)

              @chunks.each do |chunk|
                source.chunk = chunk
                process_items(source, processor)
              end

              report_result(processor)
            ensure
              processor.cleanup
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
        batched = processor.class.batched?
        progress = warnings = errors = 0

        units(source, processor).each do |unit|
          tracker.reset_stats!

          if batched
            process_batch(processor, tracker, unit)
          else
            process_item(processor, tracker, unit)
          end

          stats = tracker.stats
          progress += stats.progress
          warnings += stats.warning_count
          errors += stats.error_count

          next if progress < REPORT_INTERVAL
          @channel.report_progress(progress:, warnings:, errors:)
          progress = warnings = errors = 0
        end

        return if progress.zero? && warnings.zero? && errors.zero?
        @channel.report_progress(progress:, warnings:, errors:)
      end

      # A row, or a slice of rows for a batched processor. `each_slice` reads
      # lazily, so a worker holds one slice at a time.
      def units(source, processor)
        batch_size = processor.class.batch_size
        batch_size ? source.items.each_slice(batch_size) : source.items
      end

      def process_item(processor, tracker, item)
        processor.process(item)
      rescue StandardError => e
        tracker.log_error(I18n.t("converter.log.item_failed"), exception: e, details: item)
      end

      def process_batch(processor, tracker, items)
        tracker.progress = items.size
        processor.process_batch(items)
      rescue StandardError => e
        tracker.log_error(
          I18n.t("converter.log.batch_failed"),
          exception: e,
          details: batch_details(items),
        )
      end

      def batch_details(value)
        case value
        when Array
          value.map { |item| batch_details(item) }
        when Hash
          value.transform_values { |item| batch_details(item) }
        when String
          return value if value.length <= MAX_LOGGED_STRING_LENGTH

          "#{value[0, MAX_LOGGED_STRING_LENGTH - 3]}..."
        else
          value
        end
      end

      # The worker's one map/reduce message: the processor's accumulated result,
      # sent to the parent over the same channel as progress. For nil, nothing
      # is sent.
      def report_result(processor)
        result = processor.result
        @channel.report_result(result) unless result.nil?
      end
    end
  end
end
