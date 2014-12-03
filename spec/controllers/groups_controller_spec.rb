require 'spec_helper'

describe GroupsController do
  let(:group) { Fabricate(:group) }

  describe 'show' do
    it "ensures the group can be seen" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(false)
      xhr :get, :show, id: group.name
      response.should_not be_success
    end

    it "responds with JSON" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      xhr :get, :show, id: group.name
      response.should be_success
      ::JSON.parse(response.body)['basic_group']['id'].should == group.id
    end

    it "works even with an upper case group name" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      xhr :get, :show, id: group.name.upcase
      response.should be_success
      ::JSON.parse(response.body)['basic_group']['id'].should == group.id
    end
  end

  describe "counts" do
    it "ensures the group can be seen" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(false)
      xhr :get, :counts, group_id: group.name
      response.should_not be_success
    end

    it "performs the query and responds with JSON" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      Group.any_instance.expects(:posts_for).returns(Group.none)
      xhr :get, :counts, group_id: group.name
      response.should be_success
    end
  end

  describe "posts" do
    it "ensures the group can be seen" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(false)
      xhr :get, :posts, group_id: group.name
      response.should_not be_success
    end

    it "calls `posts_for` and responds with JSON" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      Group.any_instance.expects(:posts_for).returns(Group.none)
      xhr :get, :posts, group_id: group.name
      response.should be_success
    end
  end

  describe "members" do
    it "ensures the group can be seen" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(false)
      xhr :get, :members, group_id: group.name
      response.should_not be_success
    end

    it "calls `posts_for` and responds with JSON" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      xhr :get, :posts, group_id: group.name
      response.should be_success
    end

    it "ensures that membership can be paginated" do
      5.times { group.add(Fabricate(:user)) }
      usernames = group.users.map{ |m| m['username'] }.sort

      xhr :get, :members, group_id: group.name, limit: 3
      response.should be_success
      members = JSON.parse(response.body)
      members.map{ |m| m['username'] }.should eq(usernames[0..2])

      xhr :get, :members, group_id: group.name, limit: 3, offset: 3
      response.should be_success
      members = JSON.parse(response.body)
      members.map{ |m| m['username'] }.should eq(usernames[3..4])
    end
  end

  describe "membership edit permission" do
    it "refuses membership changes to unauthorized users" do
      Guardian.any_instance.stubs(:can_edit?).with(group).returns(false)
      xhr :patch, :update, id: group.name, changes: {add: "bob"}
      response.status.should == 403
      xhr :patch, :update, id: group.name, changes: {delete: "bob"}
      response.status.should == 403
    end

    it "cannot patch automatic groups" do
      Guardian.any_instance.stubs(:is_admin?).returns(true)
      auto_group = Fabricate(:group, name: "auto_group", automatic: true)

      xhr :patch, :update, id: auto_group.name, changes: {add: "bob"}
      response.status.should == 403
    end
  end

  describe "membership edits" do
    before do
      @user1 = Fabricate(:user)
      group.add(@user1)
      group.reload

      Guardian.any_instance.stubs(:can_edit?).with(group).returns(true)
    end

    it "can make incremental adds" do
      user2 = Fabricate(:user)
      xhr :patch, :update, id: group.name, changes: {add: user2.username}
      response.status.should == 200
      group.reload
      group.users.count.should eq(2)
    end

    it "succeeds silently when adding non-existent users" do
      xhr :patch, :update, id: group.name, changes: {add: "nosuchperson"}
      response.status.should == 200
      group.reload
      group.users.count.should eq(1)
    end

    it "succeeds silently when adding duplicate users" do
      xhr :patch, :update, id: group.name, changes: {add: @user1.username}
      response.status.should == 200
      group.reload
      group.users.count.should eq([@user1])
    end

    it "can make incremental deletes" do
      xhr :patch, :update, id: group.name, changes: {delete: @user1.username}
      response.status.should == 200
      group.reload
      group.users.count.should eq(0)
    end

    it "succeeds silently when removing non-members" do
      user2 = Fabricate(:user)
      xhr :patch, :update, id: group.name, changes: {delete: user2.username}
      response.status.should == 200
      group.reload
      group.users.count.should eq(1)
    end
  end

end
