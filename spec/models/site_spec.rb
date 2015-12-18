require 'rails_helper'
require_dependency 'site'

describe Site do
  it "omits categories users can not write to from the category list" do

    ActiveRecord::Base.observers.enable :anon_site_json_cache_observer

    category = Fabricate(:category)
    user = Fabricate(:user)

    expect(Site.new(Guardian.new(user)).categories.count).to eq(2)

    category.set_permissions(:everyone => :create_post)
    category.save

    guardian = Guardian.new(user)

    expect(Site.new(guardian)
        .categories
        .keep_if{|c| c.name == category.name}
        .first
        .permission)
        .not_to eq(CategoryGroup.permission_types[:full])

    # If a parent category is not visible, the child categories should not be returned
    category.set_permissions(:staff => :full)
    category.save

    sub_category = Fabricate(:category, parent_category_id: category.id)
    expect(Site.new(guardian).categories).not_to include(sub_category)
  end

end
