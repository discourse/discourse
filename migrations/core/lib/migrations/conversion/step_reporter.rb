# frozen_string_literal: true

module Migrations
  module Conversion
    # Interface for reporting step execution to the user. `Base#run` creates
    # one reporter per run and injects it into the step executors; the
    # implementation decides how the events are rendered (see
    # `ConsoleReporter`).
    #
    # Implementations provide three methods:
    #
    # * `start_step(title)` — a step begins.
    # * `notice(message)` — an informational line scoped to the current step.
    # * `with_progress(max_progress:) { |progress| ... }` — progress tracking
    #   for the step's items. Yields an object responding to
    #   `update(increment_by:, skip_count: 0, warning_count: 0, error_count: 0)`.
    #   May be called from a thread other than the one that called
    #   `start_step` (the parallel mode's collector thread does this);
    #   implementations must tolerate that.
    class StepReporter
    end
  end
end
