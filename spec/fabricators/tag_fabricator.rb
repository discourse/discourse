Fabricator(:tag) do
  name { sequence(:name) { |i| "tag#{i + 1}" } }
end
