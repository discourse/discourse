Fabricator(:tag) do
  name { sequence(:name) { |i| "tag#{i}" } }
end
