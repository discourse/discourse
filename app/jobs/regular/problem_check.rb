# frozen_string_literal: true

module Jobs
  # This job runs a singular scheduled admin check. It is scheduled by
  # the ProblemChecks (plural) scheduled job.
  class ProblemCheck < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      identifier = args[:check_identifier]

      AdminDashboardData.execute_scheduled_check(identifier.to_sym)
    end
  end
end
