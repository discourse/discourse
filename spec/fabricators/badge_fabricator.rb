# frozen_string_literal: true

Fabricator(:badge_type) { name { sequence(:name) { |i| "Silver #{i}" } } }

Fabricator(:badge) do
  name { sequence(:name) { |i| "Badge #{i}" } }
  badge_type
end
