# frozen_string_literal: true

Fabricator(:category) do
  name { sequence(:name) { |n| "Amazing Category #{n}" } }
  skip_category_definition true
  user
end

Fabricator(:category_with_definition, from: :category) do
  skip_category_definition false
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

Fabricator(:private_category_with_definition, from: :private_category) do
  skip_category_definition false
end
Fabricator(:link_category, from: :category) do
  before_validation { |category, transients| category.topic_featured_link_allowed = true }
end

Fabricator(:mailinglist_mirror_category, from: :category) do
  email_in 'list@example.com'
  email_in_allow_strangers true
  mailinglist_mirror true
end
