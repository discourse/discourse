Fabricator(:tag) { name { sequence(:name) { |i| "tag#{i + 1}" } } }
