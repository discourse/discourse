# frozen_string_literal: true

module Jobs
  # This job looks for problem check trackers where the `target` is no
  # longer in the list of targets for that problem check and destroys
  # them, taking any admin notices with it.
  class CleanupProblemCheckTrackers < ::Jobs::Scheduled
    sidekiq_options retry: false

    every 10.minutes

    def execute(_args)
      ProblemCheck.checks.each(&:cleanup_trackers)
    end
  end
end
