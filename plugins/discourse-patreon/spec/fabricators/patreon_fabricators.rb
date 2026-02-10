# frozen_string_literal: true

Fabricator(:patreon_reward) do
  patreon_id { sequence(:patreon_reward_id) { |i| i.to_s } }
  title { sequence(:patreon_reward_title) { |i| "Reward #{i}" } }
  amount_cents 100
end

Fabricator(:patreon_patron) do
  patreon_id { sequence(:patreon_patron_id) { |i| "patron_#{i}" } }
  email { sequence(:patreon_email) { |i| "patron#{i}@example.com" } }
  amount_cents 100
end

Fabricator(:patreon_patron_reward) do
  patreon_patron
  patreon_reward
end

Fabricator(:patreon_group_reward_filter) do
  group
  patreon_reward
end

Fabricator(:patreon_sync_log) { synced_at { Time.current } }
