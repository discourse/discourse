# frozen_string_literal: true

Fabricator(:email_log) do
  user
  to_address { sequence(:address) { |i| "blah#{i}@example.com" } }
  email_type :invite
end
