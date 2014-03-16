Fabricator(:badge_type) do
  name { sequence(:name) {|i| "Silver #{i}" } }
  color_hexcode "c0c0c0"
end

Fabricator(:badge) do
  name { sequence(:name) {|i| "Badge #{i}" } }
  badge_type
end
