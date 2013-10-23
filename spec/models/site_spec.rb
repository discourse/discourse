require 'spec_helper'
require_dependency 'site'

describe Site do
  it "omits categories users can not write to from the category list" do
    category = Fabricate(:category)
    user = Fabricate(:user)

    Site.new(Guardian.new(user)).categories.count.should == 2

    category.set_permissions(:everyone => :create_post)
    category.save

    Site.new(Guardian.new(user))
        .categories
        .keep_if{|c| c.name == category.name}
        .first
        .permission
        .should_not == CategoryGroup.permission_types[:full]
  end
end
