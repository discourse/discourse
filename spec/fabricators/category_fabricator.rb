Fabricator(:category) do
  name { sequence(:name) { |n| "Amazing Category #{n}" } }
  user
end

Fabricator(:diff_category, from: :category) do
  name "Different Category"
  user
end

Fabricator(:happy_category, from: :category) do
  name 'Happy Category'
  slug 'happy'
  user
end

Fabricator(:private_category, from: :category) do
  transient :group

  name 'Private Category'
  slug 'private'
  user
  after_build do |cat, transients|
    cat.update!(read_restricted: true)
    cat.category_groups.build(group_id: transients[:group].id, permission_type: CategoryGroup.permission_types[:full])
  end
end

Fabricator(:link_category, from: :category) do
  before_validation { |category, transients| category.topic_featured_link_allowed = true }
end
