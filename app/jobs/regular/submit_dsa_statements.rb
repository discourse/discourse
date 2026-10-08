# frozen_string_literal: true
module Jobs
  class SubmitDsaStatements < ::Jobs::Base
    cluster_concurrency 1

    def execute(_args)
      return unless SiteSetting.dsa_reporting_enabled

      statements =
        DsaStatementOfReason.transaction do
          DsaStatementOfReason
            .ready
            .order(:id)
            .limit(100)
            .lock
            .to_a
            .tap { |batch| batch.each(&:begin_attempt!) }
        end
      DsaStatementApi.new.submit(statements: statements) if statements.present?
      Jobs.enqueue(:submit_dsa_statements) if DsaStatementOfReason.ready.exists?
    end
  end
end
