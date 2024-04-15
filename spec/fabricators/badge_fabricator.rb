# frozen_string_literal: true

Fabricator(:badge_type) { name { sequence(:name) { |i| "Silver #{i}" } } }

Fabricator(:badge) do
  name { sequence(:name) { |i| "Badge #{i}" } }
  badge_type
end

Fabricator(:manually_grantable_badge, from: :badge) do
  system false
  query nil
end
