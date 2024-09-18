# frozen_string_literal: true

module Jobs
  # This job runs all of the scheduled problem checks for the admin dashboard
  # on a regular basis. To add a problem check, add a new class that inherits
  # the `ProblemCheck` base class.
  class RunProblemChecks < ::Jobs::Scheduled
    sidekiq_options retry: false

    every 10.minutes

    def execute(_args)
      scheduled_checks =
        ProblemCheckTracker.all.filter_map do |tracker|
          tracker.check if eligible_for_this_run?(tracker)
        end

      scheduled_checks.each do |check|
        Jobs.enqueue(:run_problem_check, check_identifier: check.identifier.to_s)
      end
    end

    private

    def eligible_for_this_run?(tracker)
      tracker.check.present? && tracker.check.enabled? && tracker.check.scheduled? &&
        tracker.ready_to_run?
    end
  end
end
