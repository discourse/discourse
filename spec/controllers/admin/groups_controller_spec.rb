require 'spec_helper'

describe Admin::GroupsController do
  it "is a subclass of AdminController" do
    (Admin::GroupsController < Admin::AdminController).should be_true
  end

  it "produces valid json for groups" do
    admin = log_in(:admin)
    group = Fabricate.build(:group, name: "test")
    group.add(admin)
    group.save

    xhr :get, :index
    response.status.should == 200
    ::JSON.parse(response.body).should == [{
      "id"=>group.id,
      "name"=>group.name,
      "user_count"=>1,
      "automatic"=>false
    }]
  end

  it "is able to refresh automatic groups" do
    admin = log_in(:admin)
    Group.expects(:refresh_automatic_groups!).returns(true)

    xhr :post, :refresh_automatic_groups
    response.status.should == 200
  end
end
