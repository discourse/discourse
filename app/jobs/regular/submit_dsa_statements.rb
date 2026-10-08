# frozen_string_literal: true
module Jobs
  class SubmitDsaStatements < ::Jobs::Base
    def execute(_args)
      return unless SiteSetting.dsa_reporting_enabled

      database = RailsMultisite::ConnectionManagement.current_db
      DistributedMutex.synchronize("submit_dsa_statements_#{database}", validity: 30.minutes) do
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
end
