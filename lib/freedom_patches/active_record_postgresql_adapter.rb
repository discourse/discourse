# frozen_string_literal: true

# Pulls in https://github.com/rails/rails/pull/42368 early since the query is
# definitely more efficient as it does not involved the PG planner.
# Remove once Rails 7 has been released.
module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      def active?
        @lock.synchronize do
          @connection.query ";"
        end
        true
      rescue PG::Error
        false
      end
    end
  end
end
