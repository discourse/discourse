# frozen_string_literal: true

module Migrations
  module Conversion
    # Runs the conversion steps concurrently and follows their dependency graph.
    # Each running step gets its own {StepCoordinator} on its own thread, which
    # forks one worker that reads the step's source and writes its shard. This
    # class only decides what may start: up to `budget` steps run at once (the
    # smaller of the fork budget and `--max-parallel-steps`), and a step starts
    # only once its dependencies are done.
    #
    # We don't do slot accounting or full-pool exclusivity here. Every step is
    # one fork, so "how many run at once" is the whole scheduling decision. When
    # a heavy step is split across several forks, those count as several entries
    # in the same budget.
    class StepScheduler
      FINISHED_STATES = %i[done failed skipped].freeze

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
        @step_classes = step_classes
        @reporter = reporter
        @step_factory = step_factory
        @shard_manager = shard_manager
        @writer = writer
        @no_fork = no_fork

        @budget = [budget, max_parallel_steps].compact.min
        @budget = 1 if @budget < 1
        # Inline runs share one process and one IntermediateDB connection, so
        # only one step may run at a time.
        @budget = 1 if @no_fork

        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @fork_mutex = Mutex.new

        @states = step_classes.to_h { |step_class| [step_class, :pending] }
        @available_forks = @budget
        # A running step_class => the forks it still holds. Goes down as workers
        # finish (`release_forks`); the rest returns when the step ends
        # (`step_finished`).
        @reserved_forks = {}
        @preplans = {}
        @threads = []
        @failures = {}
        @merge_errors = []
      end

      attr_reader :budget

      def run
        started_at = monotonic_time
        # Compact the heap before any fork so children share its pages copy-on-write.
        Process.warmup
        @consolidator = Consolidator.new(@shard_manager, @writer, @fork_mutex)

        @mutex.synchronize do
          loop do
            schedule
            break if all_finished?
            @condition.wait(@mutex)
          end
        end

        @threads.each(&:join)
        join_leftover_preplans
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
        @mutex.synchronize do
          # Never give back more than the step still holds; `step_finished` returns the rest.
          freed = [count, @reserved_forks[step_class] || 0].min
          next if freed <= 0

          @reserved_forks[step_class] -= freed
          @available_forks += freed
          @condition.broadcast
        end
      end

      private

      def schedule
        # A running partitioned step frees its forks one at a time. Another
        # partitioned step can't start until it fully ends anyway (two don't fit at
        # once), so those freed forks are only useful for single-fork steps for now.
        partitioned_running =
          @states.any? { |step_class, state| state == :running && step_class.partitionable? }

        ready_steps.each do |step_class|
          forks = forks_for(step_class)
          if forks > @available_forks
            # Waiting for forks is exactly the window to count in: compute the
            # step's plan now so it doesn't spend its first seconds counting once
            # the forks finally free up.
            preplan(step_class, forks)
            # Let single-fork steps use a running partitioned step's freed forks
            # instead of idling. With nothing partitioned running, stop instead, so
            # a waiting partitioned step can gather the whole budget at once.
            next if partitioned_running
            break
          end

          @states[step_class] = :running
          @available_forks -= forks
          @reserved_forks[step_class] = forks
          spawn_coordinator(step_class, forks)
          partitioned_running ||= step_class.partitionable?
        end
      end

      # A partitioned step takes all but one fork, leaving one free so single-fork
      # steps can still trickle through and overlap it.
      def forks_for(step_class)
        return 1 unless step_class.partitionable?
        [@budget - 1, 1].max
      end

      # Computes a fork-starved step's plan (row count + partition boundaries) in
      # the background, overlapped with the steps still holding the forks; the
      # coordinator picks it up through `Thread#value` when the step starts. One
      # live planner at a time keeps the extra load on the source bounded. Safe
      # because `fork_count` is deterministic (`forks_for`) and the source is
      # static — the plan is the same one the coordinator would compute later.
      def preplan(step_class, fork_count)
        return if @no_fork
        return if @preplans.key?(step_class)
        return if @preplans.values.any?(&:alive?)

        @preplans[step_class] = Thread.new do
          Thread.current.name = "plan_#{step_class.name.demodulize}"
          # The coordinator surfaces a planning failure via `value`; without this,
          # the thread would also report the exception to stderr on its own.
          Thread.current.report_on_exception = false
          StepCoordinator.compute_plan(step_class:, step_factory: @step_factory, fork_count:)
        end
      end

      def spawn_coordinator(step_class, fork_count)
        coordinator = build_coordinator(step_class, fork_count, @preplans.delete(step_class))

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

      def build_coordinator(step_class, fork_count, plan)
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
          plan:,
        )
      end

      # A preplanned step that got skipped (its dependency failed) leaves its
      # planner behind; let it finish so its source connection cleans up. Its
      # failure, if any, has no step to fail — the step never ran.
      def join_leftover_preplans
        @preplans.each_value do |planner|
          planner.join
        rescue StandardError
          # ignored
        end
      end

      def step_finished(step_class, outcome)
        @mutex.synchronize do
          # Whatever the step didn't already hand back through `release_forks`.
          @available_forks += @reserved_forks.delete(step_class) || 0
          @states[step_class] = outcome
          skip_dependents(step_class) if outcome == :failed
          @condition.broadcast
        end
      end

      def skip_dependents(failed_step_class)
        loop do
          newly_skipped =
            @step_classes.select do |step_class|
              @states[step_class] == :pending &&
                dependencies_of(step_class).any? do |dependency|
                  %i[failed skipped].include?(@states[dependency])
                end
            end

          break if newly_skipped.empty?
          newly_skipped.each { |step_class| @states[step_class] = :skipped }
        end
      end

      # The ready steps in admission order, so `schedule` tries the partitioned step
      # first and only falls through to single-fork steps for the forks it can't use.
      def ready_steps
        @step_classes
          .select { |step_class| ready?(step_class) }
          .sort_by { |step_class| admission_key(step_class) }
      end

      def ready?(step_class)
        @states[step_class] == :pending &&
          dependencies_of(step_class).all? { |dependency| @states[dependency] == :done }
      end

      def dependencies_of(step_class)
        step_class.dependencies & @step_classes
      end

      # Partitioned steps first (so they reach the front and gather their forks),
      # then by priority (lower first, unset last), then by class name.
      def admission_key(step_class)
        priority = step_class.priority
        [
          step_class.partitionable? ? 0 : 1,
          priority.nil? ? 1 : 0,
          priority || 0,
          step_class.name.to_s,
        ]
      end

      def all_finished?
        @states.each_value.all? { |state| FINISHED_STATES.include?(state) }
      end

      def report_summary(runtime)
        outcomes = @states.values
        @reporter.report_summary(
          runtime:,
          total: outcomes.size,
          failed: outcomes.count(:failed),
          skipped: outcomes.count(:skipped),
        )
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def raise_summary_if_unsuccessful
        failed = @states.select { |_, state| state == :failed }.keys
        skipped = @states.select { |_, state| state == :skipped }.keys
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
