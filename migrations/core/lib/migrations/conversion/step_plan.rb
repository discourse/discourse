# frozen_string_literal: true

module Migrations
  module Conversion
    # The scheduling decisions behind {StepScheduler}, with no threading. Given the
    # steps, the fork budget and which steps have finished, it decides what may
    # start next and how many forks each takes, and tracks the running/finished
    # state. StepScheduler owns the threads and mutex and calls in here for every
    # decision, so this logic can be tested on its own without spawning anything.
    class StepPlan
      FINISHED_STATES = %i[done failed skipped].freeze

      # @param step_classes [Array<Class<Step>>] every step in the run, in any order
      # @param budget [Integer] the most forks to run at once, usually cores - 1
      # @param max_parallel_steps [Integer, nil] a lower cap from `--max-parallel-steps`
      # @param no_fork [Boolean] run each step inline, one at a time (`--no-fork`)
      def initialize(step_classes:, budget:, max_parallel_steps: nil, no_fork: false)
        @step_classes = step_classes

        @budget = [budget, max_parallel_steps].compact.min
        @budget = 1 if @budget < 1
        # Inline runs share one process and one IntermediateDB connection, so
        # only one step may run at a time.
        @budget = 1 if no_fork

        @states = step_classes.to_h { |step_class| [step_class, :pending] }
        @available_forks = @budget
        # A running step_class => the forks it still holds. Goes down as workers
        # finish (`release_forks`); the rest returns when the step ends
        # (`step_finished`).
        @reserved_forks = {}
      end

      attr_reader :budget

      # The steps that may start now, as `[step_class, forks]`. Marks them running
      # and reserves their forks, so a later call only returns what became newly
      # startable.
      # @return [Array<Array(Class<Step>, Integer)>]
      def startable
        started = []

        # A running partitioned step frees its forks one at a time. Another
        # partitioned step can't start until it fully ends anyway (two don't fit at
        # once), so those freed forks are only useful for single-fork steps for now.
        partitioned_running =
          @states.any? { |step_class, state| state == :running && step_class.partitionable? }

        ready_steps.each do |step_class|
          forks = forks_for(step_class)
          if forks > @available_forks
            # Let single-fork steps use a running partitioned step's freed forks
            # instead of idling. With nothing partitioned running, stop instead, so
            # a waiting partitioned step can gather the whole budget at once.
            next if partitioned_running
            break
          end

          @states[step_class] = :running
          @available_forks -= forks
          @reserved_forks[step_class] = forks
          started << [step_class, forks]
          partitioned_running ||= step_class.partitionable?
        end

        started
      end

      # Gives a step's forks back to the budget as its workers finish, not only
      # when the whole step ends.
      # @return [Integer] how many forks were actually returned (0 if none)
      def release_forks(step_class, count)
        # Never give back more than the step still holds; `step_finished` returns the rest.
        freed = [count, @reserved_forks[step_class] || 0].min
        return 0 if freed <= 0

        @reserved_forks[step_class] -= freed
        @available_forks += freed
        freed
      end

      # Records a step's terminal outcome, returns its remaining forks to the
      # budget, and propagates skips to dependents when it failed.
      def step_finished(step_class, outcome)
        # Whatever the step didn't already hand back through `release_forks`.
        @available_forks += @reserved_forks.delete(step_class) || 0
        @states[step_class] = outcome
        skip_dependents if outcome == :failed
      end

      def finished?
        @states.each_value.all? { |state| FINISHED_STATES.include?(state) }
      end

      def outcome_counts
        outcomes = @states.values
        { total: outcomes.size, failed: outcomes.count(:failed), skipped: outcomes.count(:skipped) }
      end

      def failed_steps
        @states.select { |_, state| state == :failed }.keys
      end

      def skipped_steps
        @states.select { |_, state| state == :skipped }.keys
      end

      private

      # A partitioned step takes all but one fork, leaving one free so single-fork
      # steps can still trickle through and overlap it.
      def forks_for(step_class)
        return 1 unless step_class.partitionable?
        [@budget - 1, 1].max
      end

      # The ready steps in admission order, so `startable` tries the partitioned
      # step first and only falls through to single-fork steps for the forks it
      # can't use.
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

      # Skips every step still pending that has a failed or skipped dependency,
      # looping so a fresh skip cascades to its own dependents.
      def skip_dependents
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
    end
  end
end
