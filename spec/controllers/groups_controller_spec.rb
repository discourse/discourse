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
  end
end
