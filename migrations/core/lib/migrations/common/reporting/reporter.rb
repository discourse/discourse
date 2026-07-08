# frozen_string_literal: true

module Migrations
  module Reporting
    # Reports the progress of a run to the user. A run has one reporter. Call
    # `start_step` to begin a step; it returns a {StepHandle} for that step. Each
    # step gets its own id. The caller never sees the id, but it lets the reporter
    # keep each step's notices and progress apart. This holds even when steps run
    # at the same time, report from another thread, or have the same title.
    #
    # {Tui} and {Plain} are the two reporters; {Factory} picks one. Each one
    # implements the methods below and `close`. {StepHandle} and {Progress} are
    # shared by both. This lives in `common` because the importer reports the same
    # way.
    class Reporter
      def initialize
        @step_seq = 0
        @step_seq_mutex = Mutex.new
      end

      # Starts a step and returns a handle for it. The id stays internal; the
      # caller only uses the handle.
      def start_step(title)
        id = @step_seq_mutex.synchronize { @step_seq += 1 }
        report_start(id, title)
        StepHandle.new(self, id)
      end

      # Shows a transient "finishing up" status while the block runs, then clears
      # it. Used for the tail of a run where every step is done but background work
      # (merging shards) is still finishing, so the display doesn't just sit at
      # 100%. Returns the block's value.
      def finalizing
        report_finalizing_begin
        yield
      ensure
        report_finalizing_end
      end

      # Prints the end-of-run summary line: the total runtime and how many steps
      # ran (with any that failed or were skipped).
      # @param runtime [Float] the run's wall-clock seconds
      # @param total [Integer] how many steps the run had
      # @param failed [Integer] how many failed
      # @param skipped [Integer] how many were skipped because a dependency failed
      def report_summary(runtime:, total:, failed:, skipped:)
      end

      # Prints a run-level line under the summary, unattached to any step. Used for
      # an end-of-run hint (e.g. links that pointed at an unconfigured host). The
      # caller passes the whole formatted line.
      # @param message [String] the line to print
      def report_summary_notice(message)
      end

      # The run is over and nothing else will be reported. Free anything held
      # here. Called once per run, also when the run fails.
      def close
      end

      # --- The methods each reporter implements. {StepHandle} calls them. They
      # use the step id to tell steps apart; only `report_start` also gets the
      # title. ---

      def report_start(_id, _title)
        raise NotImplementedError
      end

      def report_notice(_id, _message)
        raise NotImplementedError
      end

      def report_progress_begin(_id, _max_progress)
        raise NotImplementedError
      end

      def report_concurrency(_id, _count)
        raise NotImplementedError
      end

      def report_progress(_id, _current, _skip_count, _warning_count, _error_count)
        raise NotImplementedError
      end

      # `outcome` is `:done`, `:interrupted`, or `:failed`.
      def report_finish(_id, _outcome)
        raise NotImplementedError
      end

      # Show and clear the transient "finishing up" status; `finalizing` wraps them.
      def report_finalizing_begin
      end

      def report_finalizing_end
      end

      # A handle for one step. It holds the step's id, so everything it reports
      # goes to the right step, no matter which thread calls it.
      class StepHandle
        def initialize(reporter, id)
          @reporter = reporter
          @id = id
        end

        def notice(message)
          @reporter.report_notice(@id, message)
        end

        def report_concurrency(count)
          @reporter.report_concurrency(@id, count)
        end

        def begin_progress(max_progress:)
          @reporter.report_progress_begin(@id, max_progress)
          Progress.new(@reporter, @id)
        end

        # Yields a {Progress}. You may call its `update` from any thread. Pass
        # `max_progress: nil` when the total is not known.
        def with_progress(max_progress:)
          yield begin_progress(max_progress:)
        end

        # Ends the step. It runs from an `ensure`, so `$!` (the exception in
        # flight, if any) tells us how the step ended: a SignalException means
        # Ctrl-C (interrupted), any other exception means it failed, and no
        # exception means it finished cleanly.
        def finish
          outcome =
            case $!
            when nil
              :done
            when SignalException
              :interrupted
            else
              :failed
            end

          @reporter.report_finish(@id, outcome)
        end
      end

      # Adds up the per-batch counts the executor reports and keeps the running
      # totals, then sends them on to the reporter. Thread-safe: calling `update`
      # from several threads at once still gives correct totals.
      class Progress
        def initialize(reporter, id)
          @reporter = reporter
          @id = id
          @current = 0
          @skip_count = 0
          @warning_count = 0
          @error_count = 0
          @mutex = Mutex.new
        end

        def update(increment_by:, skip_count: 0, warning_count: 0, error_count: 0)
          @mutex.synchronize do
            @current += increment_by
            @skip_count += skip_count
            @warning_count += warning_count
            @error_count += error_count
            @reporter.report_progress(@id, @current, @skip_count, @warning_count, @error_count)
          end
        end
      end
    end
  end
end
