require 'spec_helper'

describe Admin::GroupsController do

  before do
    @admin = log_in(:admin)
  end

  it "is a subclass of AdminController" do
    (Admin::GroupsController < Admin::AdminController).should == true
  end

  context ".index" do

    it "produces valid json for groups" do
      group = Fabricate.build(:group, name: "test")
      group.add(@admin)
      group.save

      xhr :get, :index
      response.status.should == 200
      ::JSON.parse(response.body).keep_if {|r| r["id"] == group.id }.should == [{
        "id"=>group.id,
        "name"=>group.name,
        "user_count"=>1,
        "automatic"=>false,
        "alias_level"=>0,
        "visible"=>true
      }]
    end

  end

  context ".create" do

    it "strip spaces on the group name" do
      xhr :post, :create, name: " bob "

      response.status.should == 200

      groups = Group.where(name: "bob").to_a

      groups.count.should == 1
      groups[0].name.should == "bob"
    end

  end

  context ".update" do

    it "ignore name change on automatic group" do
      xhr :put, :update, id: 1, name: "WAT", visible: "true"
      response.should be_success

      group = Group.find(1)
      group.name.should_not == "WAT"
      group.visible.should == true
    end

  end

  context ".destroy" do

    it "returns a 422 if the group is automatic" do
      group = Fabricate(:group, automatic: true)
      xhr :delete, :destroy, id: group.id
      response.status.should == 422
      Group.where(id: group.id).count.should == 1
    end

    it "is able to destroy a non-automatic group" do
      group = Fabricate(:group)
      xhr :delete, :destroy, id: group.id
      response.status.should == 200
      Group.where(id: group.id).count.should == 0
    end

  end

  context ".refresh_automatic_groups" do

    it "is able to refresh automatic groups" do
      Group.expects(:refresh_automatic_groups!).returns(true)

      xhr :post, :refresh_automatic_groups
      response.status.should == 200
    end

  end

  context ".add_members" do

    it "cannot add members to automatic groups" do
      xhr :put, :add_members, group_id: 1, usernames: "l77t"
      response.status.should == 422
    end

    it "is able to add several members to a group" do
      user1 = Fabricate(:user)
      user2 = Fabricate(:user)
      group = Fabricate(:group)

      xhr :put, :add_members, group_id: group.id, usernames: [user1.username, user2.username].join(",")

      response.should be_success
      group.reload
      group.users.count.should == 2
    end

  end

  context ".remove_member" do

    it "cannot remove members from automatic groups" do
      xhr :put, :remove_member, group_id: 1, user_id: 42
      response.status.should == 422
    end

    it "is able to remove a member" do
      group = Fabricate(:group)
      user = Fabricate(:user)
      group.add(user)
      group.save

      xhr :delete, :remove_member, group_id: group.id, user_id: user.id

      response.should be_success
      group.reload
      group.users.count.should == 0
    end

  end

end
