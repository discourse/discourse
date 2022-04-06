# frozen_string_literal: true

Fabricator(:associated_group) do
  name { sequence(:name) { |n| "group_#{n}" } }
  provider_name 'google'
  provider_id { SecureRandom.hex(20) }
end
