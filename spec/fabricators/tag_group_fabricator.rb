Fabricator(:tag_group) do
  name { sequence(:name) { |i| "tag_group_#{i}" } }
end
