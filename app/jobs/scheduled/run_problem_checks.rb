# frozen_string_literal: true

module Jobs
  # This job runs all of the scheduled problem checks for the admin dashboard
  # on a regular basis. To add a problem check, add a new class that inherits
  # the `ProblemCheck` base class.
  class RunProblemChecks < ::Jobs::Scheduled
    sidekiq_options retry: false

    every 10.minutes

    def execute(_args)
      ProblemCheck.scheduled.filter_map do |check|
        if eligible_for_this_run?(check)
          Jobs.enqueue(:run_problem_check, check_identifier: check.identifier.to_s)
        end
      end
    end

    private

    def eligible_for_this_run?(check)
      check.enabled? && check.ready_to_run?
    end
  end
end
