require 'spec_helper'

describe Admin::GroupsController do

  before do
    @admin = log_in(:admin)
  end

  it "is a subclass of AdminController" do
    expect(Admin::GroupsController < Admin::AdminController).to eq(true)
  end

  context ".index" do

    it "produces valid json for groups" do
      group = Fabricate.build(:group, name: "test")
      group.add(@admin)
      group.save

      xhr :get, :index
      expect(response.status).to eq(200)
      expect(::JSON.parse(response.body).keep_if {|r| r["id"] == group.id }).to eq([{
        "id"=>group.id,
        "name"=>group.name,
        "user_count"=>1,
        "automatic"=>false,
        "alias_level"=>0,
        "visible"=>true,
        "automatic_membership_email_domains"=>nil,
        "automatic_membership_retroactive"=>false,
        "title"=>nil,
        "primary_group"=>false,
        "grant_trust_level"=>nil
      }])
    end

  end

  context ".create" do

    it "strip spaces on the group name" do
      xhr :post, :create, name: " bob "

      expect(response.status).to eq(200)

      groups = Group.where(name: "bob").to_a

      expect(groups.count).to eq(1)
      expect(groups[0].name).to eq("bob")
    end

  end

  context ".update" do

    it "ignore name change on automatic group" do
      xhr :put, :update, id: 1, name: "WAT", visible: "true"
      expect(response).to be_success

      group = Group.find(1)
      expect(group.name).not_to eq("WAT")
      expect(group.visible).to eq(true)
    end

    it "doesn't launch the 'automatic group membership' job when it's not retroactive" do
      Jobs.expects(:enqueue).never
      group = Fabricate(:group)
      xhr :put, :update, id: group.id, automatic_membership_retroactive: "false"
      expect(response).to be_success
    end

    it "launches the 'automatic group membership' job when it's retroactive" do
      group = Fabricate(:group)
      Jobs.expects(:enqueue).with(:automatic_group_membership, group_id: group.id)
      xhr :put, :update, id: group.id, automatic_membership_retroactive: "true"
      expect(response).to be_success
    end

  end

  context ".destroy" do

    it "returns a 422 if the group is automatic" do
      group = Fabricate(:group, automatic: true)
      xhr :delete, :destroy, id: group.id
      expect(response.status).to eq(422)
      expect(Group.where(id: group.id).count).to eq(1)
    end

    it "is able to destroy a non-automatic group" do
      group = Fabricate(:group)
      xhr :delete, :destroy, id: group.id
      expect(response.status).to eq(200)
      expect(Group.where(id: group.id).count).to eq(0)
    end

  end

  context ".refresh_automatic_groups" do

    it "is able to refresh automatic groups" do
      Group.expects(:refresh_automatic_groups!).returns(true)

      xhr :post, :refresh_automatic_groups
      expect(response.status).to eq(200)
    end

  end

  context ".add_members" do

    it "cannot add members to automatic groups" do
      xhr :put, :add_members, id: 1, usernames: "l77t"
      expect(response.status).to eq(422)
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

    it "cannot remove members from automatic groups" do
      xhr :put, :remove_member, id: 1, user_id: 42
      expect(response.status).to eq(422)
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

end
