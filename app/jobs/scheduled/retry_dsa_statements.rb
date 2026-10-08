# frozen_string_literal: true
module Jobs
  class RetryDsaStatements < ::Jobs::Scheduled
    every 1.minute

    def execute(_args)
      return unless SiteSetting.dsa_reporting_enabled

      Jobs.enqueue(:submit_dsa_statements) if DsaStatementOfReason.ready.exists?
    end
  end
end
