# frozen_string_literal: true

module Migrations
  # Interface for reporting step execution to the user. A run creates one
  # reporter and injects it into the step executors; the implementation
  # decides how the events are rendered (see `Conversion::ConsoleReporter`).
  # It lives in `common` because the importer will report through the same
  # interface.
  #
  # Implementations provide five methods:
  #
  # * `start_step(title)` — a step begins.
  # * `notice(message)` — an informational line scoped to the current step.
  # * `with_progress(max_progress:) { |progress| ... }` — progress tracking
  #   for the step's items. Yields an object responding to
  #   `update(increment_by:, skip_count: 0, warning_count: 0, error_count: 0)`.
  #   May be called from a thread other than the one that called
  #   `start_step` (the parallel mode's collector thread does this);
  #   implementations must tolerate that.
  # * `finish_step(title)` — the step ended; also called when it failed
  #   (the executors call it from an `ensure`).
  # * `close` — the run ended and no further calls will follow; release
  #   anything the reporter holds. Called once per run, also on failure.
  class StepReporter
  end
end
