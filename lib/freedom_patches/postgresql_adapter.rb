# frozen_string_literal: true

# Awaiting decision on https://github.com/rails/rails/issues/31190
if ENV['DISABLE_MIGRATION_ADVISORY_LOCK']
  class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
    def supports_advisory_locks?
      false
    end
  end
end
