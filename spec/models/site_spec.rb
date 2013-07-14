require 'spec_helper'
require_dependency 'site'

describe Site do
  it "omits categories users can not write to from the category list" do
    category = Fabricate(:category)
    user = Fabricate(:user)

    Site.new(Guardian.new(user)).categories.count.should == 1

    category.set_permissions(:everyone => :create_post)
    category.save

    Site.new(Guardian.new(user)).categories.count.should == 0
  end
end
