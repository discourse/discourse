Fabricator(:group) do
  name { sequence(:name) { |n| "my_group_#{n}" } }
end

Fabricator(:public_group, from: :group) do
  public_admission true
  public_exit true
end
