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
      TERMINAL_STATES = %i[done failed skipped].freeze

      # @param step_classes [Array<Class<Step>>] every step in the run, in any order
      # @param reporter [Reporting::Reporter] shared by all steps to report progress
      # @param step_factory [#call] builds a step from its class, `->(step_class) { step }`
      # @param shard_manager [ShardManager] hands out the per-worker shard databases
      # @param budget [Integer] the most steps (forks) to run at once, usually cores - 1
      # @param max_parallel_steps [Integer, nil] a lower cap from `--max-parallel-steps`
      # @param no_fork [Boolean] run each step inline, one at a time (`--no-fork`)
      def initialize(
        step_classes:,
        reporter:,
        step_factory:,
        shard_manager:,
        budget:,
        max_parallel_steps: nil,
        no_fork: false
      )
        @step_classes = step_classes
        @reporter = reporter
        @step_factory = step_factory
        @shard_manager = shard_manager
        @no_fork = no_fork

        @budget = [budget, max_parallel_steps].compact.min
        @budget = 1 if @budget < 1
        # Inline runs share one process and one IntermediateDB connection, so
        # only one step may run at a time.
        @budget = 1 if @no_fork

        @mutex = Mutex.new
        @cond = ConditionVariable.new
        @fork_mutex = Mutex.new

        @states = step_classes.to_h { |step_class| [step_class, :pending] }
        @available = @budget
        @demands = {} # step_class => forks it's using
        @threads = []
        @failures = {}
        @merge_errors = []
      end

      attr_reader :budget

      def run
        started_at = monotonic
        # Compact the heap before any fork so children share its pages copy-on-write.
        Process.warmup
        @consolidator = Consolidator.new(@shard_manager)

        @mutex.synchronize do
          loop do
            schedule
            break if all_terminal?
            @cond.wait(@mutex)
          end
        end

        @threads.each(&:join)
        # Every step is done, but the background merges may still be catching up.
        # Show a "finishing up" status until they drain, so the display doesn't sit
        # silently at 100%.
        @merge_errors = @reporter.finalizing { @consolidator.drain }
        report_summary(monotonic - started_at)
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

      private

      def schedule
        loop do
          step_class = next_ready_step
          break unless step_class

          forks = fork_demand(step_class)
          # Stop (don't skip past) when the next step can't get its forks yet, so
          # a partitioned step can gather the budget instead of single-fork steps
          # nibbling it away.
          break if forks > @available

          @states[step_class] = :running
          @available -= forks
          @demands[step_class] = forks
          spawn_coordinator(step_class, forks)
        end
      end

      # A partitioned step takes all but one fork, leaving one free so single-fork
      # steps can still trickle through and overlap it.
      def fork_demand(step_class)
        return 1 unless step_class.partitionable?
        [@budget - 1, 1].max
      end

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
          @available += @demands.delete(step_class)
          @states[step_class] = outcome
          skip_dependents(step_class) if outcome == :failed
          @cond.broadcast
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

      def next_ready_step
        ready = @step_classes.select { |step_class| ready?(step_class) }
        ready.min_by { |step_class| admission_key(step_class) }
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

      def all_terminal?
        @states.each_value.all? { |state| TERMINAL_STATES.include?(state) }
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

      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def raise_summary_if_unsuccessful
        failed = @states.select { |_, state| state == :failed }.keys
        skipped = @states.select { |_, state| state == :skipped }.keys
        return if failed.empty? && skipped.empty? && @merge_errors.empty?

        raise ConvertError, build_summary(failed, skipped)
      end

      def build_summary(failed, skipped)
        lines = ["The conversion finished with errors:"]

        failed.each do |step_class|
          error = @failures[step_class]
          lines << "  • #{step_class.title} failed: #{error&.class}: #{error&.message}"
          Array(error&.backtrace).first(5).each { |frame| lines << "      #{frame}" }
        end

        skipped.each do |step_class|
          lines << "  • #{step_class.title} was skipped because a dependency failed."
        end

        @merge_errors.each do |error|
          lines << "  • Merging a step's shard into the run database failed: " \
            "#{error.class}: #{error.message}"
        end

        lines.join("\n")
      end
    end
  end
end
