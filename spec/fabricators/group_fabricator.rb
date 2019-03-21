Fabricator(:group) { name { sequence(:name) { |n| "my_group_#{n}" } } }

Fabricator(:public_group, from: :group) do
  public_admission true
  public_exit true
end
