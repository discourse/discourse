require 'rails_helper'

describe GroupsController do
  let(:group) { Fabricate(:group) }

  describe 'show' do
    it "ensures the group can be seen" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(false)
      xhr :get, :show, id: group.name
      expect(response).not_to be_success
    end

    it "responds with JSON" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      xhr :get, :show, id: group.name
      expect(response).to be_success
      expect(::JSON.parse(response.body)['basic_group']['id']).to eq(group.id)
    end

    it "works even with an upper case group name" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      xhr :get, :show, id: group.name.upcase
      expect(response).to be_success
      expect(::JSON.parse(response.body)['basic_group']['id']).to eq(group.id)
    end
  end

  describe "counts" do
    it "returns counts if it can be seen" do
      xhr :get, :counts, group_id: group.name
      expect(response).to be_success
    end

    it "returns no counts if it can not be seen" do
      group.update_columns(visible: false)
      xhr :get, :counts, group_id: group.name
      expect(response).not_to be_success
    end
  end

  describe "posts" do
    it "ensures the group can be seen" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(false)
      xhr :get, :posts, group_id: group.name
      expect(response).not_to be_success
    end

    it "calls `posts_for` and responds with JSON" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      Group.any_instance.expects(:posts_for).returns(Group.none)
      xhr :get, :posts, group_id: group.name
      expect(response).to be_success
    end
  end

  describe "members" do
    it "ensures the group can be seen" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(false)
      xhr :get, :members, group_id: group.name
      expect(response).not_to be_success
    end

    it "calls `posts_for` and responds with JSON" do
      Guardian.any_instance.expects(:can_see?).with(group).returns(true)
      xhr :get, :posts, group_id: group.name
      expect(response).to be_success
    end

    # Pending until we fix group truncation
    skip "ensures that membership can be paginated" do
      5.times { group.add(Fabricate(:user)) }
      usernames = group.users.map{ |m| m['username'] }.sort

      xhr :get, :members, group_id: group.name, limit: 3
      expect(response).to be_success
      members = JSON.parse(response.body)
      expect(members.map{ |m| m['username'] }).to eq(usernames[0..2])

      xhr :get, :members, group_id: group.name, limit: 3, offset: 3
      expect(response).to be_success
      members = JSON.parse(response.body)
      expect(members.map{ |m| m['username'] }).to eq(usernames[3..4])
    end
  end


  describe "membership edit permission" do
    it "refuses membership changes to unauthorized users" do
      Guardian.any_instance.stubs(:can_edit?).with(group).returns(false)

      xhr :put, :add_members, id: group.id, usernames: "bob"
      expect(response).to be_forbidden

      xhr :delete, :remove_member, id: group.id, username: "bob"
      expect(response).to be_forbidden
    end

    it "cannot add members to automatic groups" do
      Guardian.any_instance.stubs(:is_admin?).returns(true)
      group = Fabricate(:group, name: "auto_group", automatic: true)

      xhr :put, :add_members, id: group.id, usernames: "bob"
      expect(response).to be_forbidden
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
      xhr :put, :add_members, id: group.id, usernames: user2.username

      expect(response).to be_success
      group.reload
      expect(group.users.count).to eq(2)
    end

    it "can make incremental deletes" do
      xhr :delete, :remove_member, id: group.id, username: @user1.username

      expect(response).to be_success
      group.reload
      expect(group.users.count).to eq(0)
    end

  end

  context ".add_members" do

    before do
      @admin = log_in(:admin)
    end

    it "cannot add members to automatic groups" do
      xhr :put, :add_members, id: 1, usernames: "l77t"
      expect(response.status).to eq(403)
    end

    context "is able to add several members to a group" do

      let(:user1) { Fabricate(:user) }
      let(:user2) { Fabricate(:user) }
      let(:group) { Fabricate(:group) }

      it "adds by username" do
        xhr :put, :add_members, id: group.id, usernames: [user1.username, user2.username].join(",")

        expect(response).to be_success
        group.reload
        expect(group.users.count).to eq(2)
      end

      it "adds by id" do
        xhr :put, :add_members, id: group.id, user_ids: [user1.id, user2.id].join(",")

        expect(response).to be_success
        group.reload
        expect(group.users.count).to eq(2)
      end
    end

    it "returns 422 if member already exists" do
      group = Fabricate(:group)
      existing_member = Fabricate(:user)
      group.add(existing_member)
      group.save

      xhr :put, :add_members, id: group.id, usernames: existing_member.username
      expect(response.status).to eq(422)
    end

  end

  context ".remove_member" do

    before do
      @admin = log_in(:admin)
    end

    it "cannot remove members from automatic groups" do
      xhr :put, :remove_member, id: 1, user_id: 42
      expect(response.status).to eq(403)
    end

    context "is able to remove a member" do

      let(:user) { Fabricate(:user) }
      let(:group) { Fabricate(:group) }

      before do
        group.add(user)
        group.save
      end

      it "removes by id" do
        xhr :delete, :remove_member, id: group.id, user_id: user.id

        expect(response).to be_success
        group.reload
        expect(group.users.count).to eq(0)
      end

      it "removes by username" do
        xhr :delete, :remove_member, id: group.id, username: user.username

        expect(response).to be_success
        group.reload
        expect(group.users.count).to eq(0)
      end

      it "removes user.primary_group_id when user is removed from group" do
        user.primary_group_id = group.id
        user.save

        xhr :delete, :remove_member, id: group.id, username: user.username

        user.reload
        expect(user.primary_group_id).to eq(nil)
      end
    end

  end

  describe '.posts_feed' do
    it 'renders RSS' do
      get :posts_feed, group_id: group.name, format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end
  end

  describe '.mentions_feed' do
    it 'renders RSS' do
      get :mentions_feed, group_id: group.name, format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end
  end

end
