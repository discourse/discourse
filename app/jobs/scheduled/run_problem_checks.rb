# frozen_string_literal: true

module Jobs
  # This job runs all of the scheduled problem checks for the admin dashboard
  # on a regular basis. To add a problem check, add a new class that inherits
  # the `ProblemCheck` base class.
  class RunProblemChecks < ::Jobs::Scheduled
    sidekiq_options retry: false

    every 10.minutes

    def execute(_args)
      # This way if the problems have been solved in the meantime, then they will
      # not be re-added by the relevant checker, and will be cleared.
      AdminDashboardData.clear_found_scheduled_check_problems

      scheduled_checks =
        ProblemCheckTracker.all.filter_map do |tracker|
          tracker.check if tracker.check.scheduled? && tracker.ready_to_run?
        end

      scheduled_checks.each do |check|
        Jobs.enqueue(:run_problem_check, check_identifier: check.identifier.to_s)
      end
    end
  end
end
