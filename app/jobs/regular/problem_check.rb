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

      check = ::ProblemCheck[identifier]

      problems = check.call
      raise RetrySignal if problems.present? && retry_count < check.max_retries

      problems.each { |problem| AdminDashboardData.add_found_scheduled_check_problem(problem) }
    rescue RetrySignal
      Jobs.enqueue_in(
        check.retry_after,
        :problem_check,
        args.merge(retry_count: retry_count + 1).stringify_keys,
      )
    rescue StandardError => err
      Discourse.warn_exception(
        err,
        message: "A scheduled admin dashboard problem check (#{identifier}) errored.",
      )
    end
  end
end
