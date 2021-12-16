# frozen_string_literal: true

module Jobs

  # This job runs all of the scheduled problem checks for the admin dashboard
  # on a regular basis. To add a problem check for this scheduled job run
  # call AdminDashboardData.add_scheduled_problem_check
  class ProblemChecks < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      found_problems = []

      # This way if the problems have been solved in the meantime, then they will
      # not be re-added by the relevant checker, and will be cleared.
      AdminDashboardData.clear_found_scheduled_check_problems

      AdminDashboardData.problem_scheduled_check_blocks.each do |check_identifier, blk|
        problems = nil

        begin
          problems = instance_exec(&blk)
        rescue StandardError => err
          Discourse.warn_exception(err, message: "A scheduled admin dashboard problem check (#{check_identifier}) errored.")
          # we don't want to hold up other checks because this one errored
          next
        end

        if !problems.is_a? Array
          problems = [problems]
        end
        found_problems += problems
      end
      found_problems.compact.each do |problem|
        AdminDashboardData.add_found_scheduled_check_problem(problem)
      end
    end
  end
end
