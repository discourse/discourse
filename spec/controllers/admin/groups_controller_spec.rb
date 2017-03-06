require 'rails_helper'

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
      json = ::JSON.parse(response.body)
      expect(json.select { |r| r["id"] == Group::AUTO_GROUPS[:everyone] }).to be_empty
      expect(json.select { |r| r["id"] == group.id }).to eq([{
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
        "grant_trust_level"=>nil,
        "incoming_email"=>nil,
        "has_messages"=>false,
        "flair_url"=>nil,
        "flair_bg_color"=>nil,
        "flair_color"=>nil,
        "bio_raw"=>nil,
        "bio_cooked"=>nil,
        "public"=>false,
        "allow_membership_requests"=>false,
        "full_name"=>group.full_name
      }])

    end

  end

  context ".bulk" do
    it "can assign users to a group by email or username" do
      group = Fabricate(:group, name: "test", primary_group: true, title: 'WAT', grant_trust_level: 3)
      user = Fabricate(:user, trust_level: 2)
      user2 = Fabricate(:user, trust_level: 4)

      xhr :put, :bulk_perform, group_id: group.id, users: [user.username.upcase, user2.email, 'doesnt_exist']

      expect(response).to be_success

      user.reload
      expect(user.primary_group).to eq(group)
      expect(user.title).to eq("WAT")
      expect(user.trust_level).to eq(3)

      user2.reload
      expect(user2.primary_group).to eq(group)
      expect(user2.title).to eq("WAT")
      expect(user2.trust_level).to eq(4)
    end
  end

  context ".create" do

    it "strip spaces on the group name" do
      xhr :post, :create, { group: { name: " bob " } }

      expect(response.status).to eq(200)

      groups = Group.where(name: "bob").to_a

      expect(groups.count).to eq(1)
      expect(groups[0].name).to eq("bob")
    end

  end

  context ".update" do

    it "ignore name change on automatic group" do
      expect do
        xhr :put, :update, { id: 1, group: {
          name: "WAT",
          visible: "true",
          allow_membership_requests: "true"
        } }
      end.to change { GroupHistory.count }.by(1)

      expect(response).to be_success

      group = Group.find(1)
      expect(group.name).not_to eq("WAT")
      expect(group.visible).to eq(true)
      expect(group.allow_membership_requests).to eq(true)
    end

    it "doesn't launch the 'automatic group membership' job when it's not retroactive" do
      Jobs.expects(:enqueue).never
      group = Fabricate(:group)
      xhr :put, :update, { id: group.id, group: { automatic_membership_retroactive: "false" } }
      expect(response).to be_success
    end

    it "launches the 'automatic group membership' job when it's retroactive" do
      group = Fabricate(:group)
      Jobs.expects(:enqueue).with(:automatic_group_membership, group_id: group.id)
      xhr :put, :update, { id: group.id, group: { automatic_membership_retroactive: "true" } }
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

end
