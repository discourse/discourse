Fabricator(:group) do
  name { sequence(:name) { |n| "my_group_#{n}" } }
end
