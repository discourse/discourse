# frozen_string_literal: true

module Jobs
  class RetrySignal < Exception
  end

  # This job runs a singular scheduled admin check. It is scheduled by
  # the ProblemChecks (plural) scheduled job.
  class ProblemCheck < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      retry_count = args[:retry_count].to_i
      identifier = args[:check_identifier].to_sym

      check = AdminDashboardData.problem_scheduled_check_klasses[identifier]

      AdminDashboardData.execute_scheduled_check(identifier) do |problems|
        raise RetrySignal if retry_count < check.max_retries
      end
    rescue RetrySignal
      Jobs.enqueue_in(
        check.retry_wait,
        :problem_check,
        args.merge(retry_count: retry_count + 1).stringify_keys,
      )
    end
  end
end
