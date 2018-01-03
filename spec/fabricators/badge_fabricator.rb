Fabricator(:badge_type) do
  name { sequence(:name) { |i| "Silver #{i}" } }
end

Fabricator(:badge) do
  name { sequence(:name) { |i| "Badge #{i}" } }
  badge_type
end
