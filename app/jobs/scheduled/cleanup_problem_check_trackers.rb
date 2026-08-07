# frozen_string_literal: true

module Jobs
  # Reconciles problem check trackers (and their admin notices) with the checks
  # that currently exist: drops trackers with a stale `target`, and trackers and
  # notices for checks that are disabled or no longer exist.
  class CleanupProblemCheckTrackers < ::Jobs::Scheduled
    sidekiq_options retry: false

    every 10.minutes

    def execute(_args)
      checks = ProblemCheck.checks
      checks.each(&:cleanup_trackers)

      known_identifiers = checks.map { |check| check.identifier.to_s }
      ProblemCheckTracker.where.not(identifier: known_identifiers).destroy_all
      AdminNotice.problem.where.not(identifier: known_identifiers).destroy_all
    end
  end
end
