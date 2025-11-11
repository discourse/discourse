# frozen_string_literal: true

module Jobs
  class RetrySignal < Exception
  end

  # This job runs a singular scheduled admin check. It is scheduled by
  # the ProblemChecks (plural) scheduled job.
  class RunProblemCheck < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      retry_count = args[:retry_count].to_i
      identifier = args[:check_identifier].to_sym
      target = args[:target].to_s

      return if target.blank?

      check = ProblemCheck[identifier]

      check
        .new(target)
        .run { |problem| raise RetrySignal if problem.present? && retry_count < check.max_retries }
    rescue RetrySignal
      Jobs.enqueue_in(
        check.retry_after,
        :run_problem_check,
        args.merge(retry_count: retry_count + 1),
      )
    rescue StandardError => err
      Discourse.warn_exception(
        err,
        message: "A scheduled admin dashboard problem check (#{identifier}) errored.",
      )
    end
  end
end
