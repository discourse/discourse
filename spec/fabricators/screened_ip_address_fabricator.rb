# frozen_string_literal: true

Fabricator(:screened_ip_address) do
  action_type ScreenedIpAddress.actions[:block]
  ip_address { sequence(:ip_address) { |i| "99.232.23.#{i % 254}" } }
  match_count { sequence(:match_count) { |n| n } }
  last_match_at { sequence(:last_match_at) { |n| Time.now + n.days } }
  created_at { sequence(:created_at) { |n| Time.now + n.days } }
end
