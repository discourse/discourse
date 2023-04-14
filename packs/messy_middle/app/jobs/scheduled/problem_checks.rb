# frozen_string_literal: true

module Jobs
  # This job runs all of the scheduled problem checks for the admin dashboard
  # on a regular basis. To add a problem check for this scheduled job run
  # call AdminDashboardData.add_scheduled_problem_check
  class ProblemChecks < ::Jobs::Scheduled
    every 10.minutes

    def execute(_args)
      # This way if the problems have been solved in the meantime, then they will
      # not be re-added by the relevant checker, and will be cleared.
      AdminDashboardData.clear_found_scheduled_check_problems
      AdminDashboardData.execute_scheduled_checks
    end
  end
end
