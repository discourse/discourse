require 'spec_helper'
require_dependency 'site'

describe Site do
  it "omits categories users can not write to from the category list" do
    category = Fabricate(:category)
    user = Fabricate(:user)

    Site.new(Guardian.new(user)).categories.count.should == 2

    category.set_permissions(:everyone => :create_post)
    category.save

    guardian = Guardian.new(user)

    Site.new(guardian)
        .categories
        .keep_if{|c| c.name == category.name}
        .first
        .permission
        .should_not == CategoryGroup.permission_types[:full]

    # If a parent category is not visible, the child categories should not be returned
    category.set_permissions(:staff => :full)
    category.save

    sub_category = Fabricate(:category, parent_category_id: category.id)
    Site.new(guardian).categories.should_not include(sub_category)
  end

end
