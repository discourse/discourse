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

  it "is able to destroy a group" do
    log_in(:admin)
    group = Fabricate(:group)

    xhr :delete, :destroy, id: group.id
    response.status.should == 200

    Group.count.should == 0
  end

  it "is able to create a group" do
    a = log_in(:admin)

    xhr :post, :create, group: {
      usernames: a.username,
      name: "bob"
    }

    response.status.should == 200

    groups = Group.all.to_a

    groups.count.should == 1
    groups[0].usernames.should == a.username
    groups[0].name.should == "bob"

  end

  it "is able to update group members" do
    user1 = Fabricate(:user)
    user2 = Fabricate(:user)
    group = Fabricate(:group)
    log_in(:admin)

    xhr :put, :update, id: group.id, name: 'fred', group: {
        name: 'fred',
        usernames: "#{user1.username},#{user2.username}"
    }

    group.reload
    group.users.count.should == 2
    group.name.should == 'fred'

  end
end
