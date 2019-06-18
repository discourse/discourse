# frozen_string_literal: true

Fabricator(:skipped_email_log) do
  to_address { sequence(:address) { |i| "blah#{i}@example.com" } }
  email_type :invite
  reason_type SkippedEmailLog.reason_types[:exceeded_emails_limit]
end
