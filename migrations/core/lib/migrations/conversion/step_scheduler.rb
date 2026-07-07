# frozen_string_literal: true

module Migrations
  module Conversion
    # Runs the conversion steps concurrently and follows their dependency graph.
    # Each running step gets its own {StepCoordinator} on its own thread, which
    # forks one worker that reads the step's source and writes its shard.
    #
    # This class owns the threads, the mutex and the fork budget's live counters;
    # every "what may start now" decision is delegated to {StepPlan}, which has no
    # threading and is tested on its own.
    class StepScheduler
      # @param step_classes [Array<Class<Step>>] every step in the run, in any order
      # @param reporter [Reporting::Reporter] shared by all steps to report progress
      # @param step_factory [#call] builds a step from its class, `->(step_class) { step }`
      # @param shard_manager [ShardManager] hands out the per-worker shard databases
      # @param writer [Database::Connection] the run DB connection the consolidator
      #   merges shards into (held directly, so an inline step swapping the
      #   IntermediateDB connection can't divert a background merge)
      # @param budget [Integer] the most steps (forks) to run at once, usually cores - 1
      # @param max_parallel_steps [Integer, nil] a lower cap from `--max-parallel-steps`
      # @param no_fork [Boolean] run each step inline, one at a time (`--no-fork`)
      def initialize(
        step_classes:,
        reporter:,
        step_factory:,
        shard_manager:,
        writer:,
        budget:,
        max_parallel_steps: nil,
        no_fork: false
      )
        @reporter = reporter
        @step_factory = step_factory
        @shard_manager = shard_manager
        @writer = writer
        @no_fork = no_fork

        @plan = StepPlan.new(step_classes:, budget:, max_parallel_steps:, no_fork:)

        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @fork_mutex = Mutex.new

        @threads = []
        @failures = {}
        @merge_errors = []
      end

      def budget
        @plan.budget
      end

      def run
        started_at = monotonic_time
        # Compact the heap before any fork so children share its pages copy-on-write.
        Process.warmup
        @consolidator = Consolidator.new(@shard_manager, @writer, @fork_mutex)

        @mutex.synchronize do
          loop do
            @plan.startable.each { |step_class, forks| spawn_coordinator(step_class, forks) }
            break if @plan.finished?
            @condition.wait(@mutex)
          end
        end

        @threads.each(&:join)
        # Every step is done, but the background merges may still be catching up.
        # Show a "finishing up" status until they drain, so the display doesn't sit
        # silently at 100%.
        @merge_errors = @reporter.finalizing { @consolidator.drain }
        report_summary(monotonic_time - started_at)
        raise_summary_if_unsuccessful
      end

      # Records a step-level error for the end-of-run summary; a coordinator calls
      # this when its step fails.
      # @param step_class [Class<Step>] the step that failed
      # @param error [StandardError] what it failed with
      # @return [void]
      def record_failure(step_class, error)
        @mutex.synchronize { @failures[step_class] = error }
      end

      # Gives a step's forks back to the budget as its workers finish, not only
      # when the whole step ends. A partitioned step's workers finish at very
      # different times, so this frees their cores while the slow ones keep going,
      # letting other steps fill the tail. The coordinator calls it once per
      # finished worker.
      # @param step_class [Class<Step>] the running step whose worker just finished
      # @param count [Integer] how many forks came free (one per finished worker)
      def release_forks(step_class, count)
        @mutex.synchronize { @condition.broadcast if @plan.release_forks(step_class, count) > 0 }
      end

      private

      def spawn_coordinator(step_class, fork_count)
        coordinator = build_coordinator(step_class, fork_count)

        @threads << Thread.new do
          Thread.current.name = "step_#{step_class.name.demodulize}"

          outcome = :failed
          begin
            outcome = coordinator.run
          rescue SignalException
            outcome = :failed
          rescue StandardError => e
            # Must be recorded even if `run` should have handled it, or the step
            # never reaches a terminal state and the scheduler waits on it forever.
            record_failure(step_class, e)
            outcome = :failed
          ensure
            step_finished(step_class, outcome)
          end
        end
      end

      def build_coordinator(step_class, fork_count)
        StepCoordinator.new(
          step_class:,
          step_factory: @step_factory,
          reporter: @reporter,
          fork_mutex: @fork_mutex,
          scheduler: self,
          shard_manager: @shard_manager,
          consolidator: @consolidator,
          fork_count:,
          no_fork: @no_fork,
        )
      end

      def step_finished(step_class, outcome)
        @mutex.synchronize do
          @plan.step_finished(step_class, outcome)
          @condition.broadcast
        end
      end

      def report_summary(runtime)
        @reporter.report_summary(runtime:, **@plan.outcome_counts)
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def raise_summary_if_unsuccessful
        failed = @plan.failed_steps
        skipped = @plan.skipped_steps
        return if failed.empty? && skipped.empty? && @merge_errors.empty?

        raise ConvertError.new(
                failures: failed.to_h { |step_class| [step_class, @failures[step_class]] },
                skipped:,
                merge_errors: @merge_errors,
              )
      end
    end
  end
end
