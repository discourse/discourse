# frozen_string_literal: true

Fabricator(:screened_email) do
  email { sequence(:email) { |n| "bad#{n}@spammers.org" } }
  action_type ScreenedEmail.actions[:block]
  match_count { sequence(:match_count) { |n| n } }
  last_match_at { sequence(:last_match_at) { |n| Time.now + n.days } }
  created_at { sequence(:created_at) { |n| Time.now + n.days } }
  ip_address { sequence(:ip_address) { |i| "99.232.23.#{i % 254}" } }
end
