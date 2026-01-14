# frozen_string_literal: true

module Jobs
  # This job runs all of the scheduled problem checks for the admin dashboard
  # on a regular basis. To add a problem check, add a new class that inherits
  # the `ProblemCheck` base class.
  class RunProblemChecks < ::Jobs::Scheduled
    sidekiq_options retry: false

    every 10.minutes

    def execute(_args)
      ProblemCheck.scheduled.filter_map do |scheduled_check|
        scheduled_check.each_target do |target|
          check = scheduled_check.new(target)

          if check.enabled? && check.ready_to_run?
            Jobs.enqueue(
              :run_problem_check,
              check_identifier: check.identifier.to_s,
              target: target.to_s,
            )
          end
        end
      end
    end
  end
end
