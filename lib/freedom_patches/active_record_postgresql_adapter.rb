# frozen_string_literal: true

# Pulls in https://github.com/rails/rails/pull/42368 early since the query is
# definitely more efficient as it does not involved the PG planner.
# Remove once Rails 7 has been released.

SanePatch.patch("activerecord", "~> 6.1.4") do
  module FreedomPatches
    module ActiveRecordPostgresqlAdapter
      def active?
        @lock.synchronize do
          @connection.query ";"
        end
        true
      rescue PG::Error
        false
      end

      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(self)
    end
  end
end
