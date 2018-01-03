require 'rails_helper'

describe Admin::GroupsController do
  let(:user) { Fabricate(:user) }
  let(:group) { Fabricate(:group) }

  before do
    @admin = log_in(:admin)
  end

  it "is a subclass of AdminController" do
    expect(Admin::GroupsController < Admin::AdminController).to eq(true)
  end

  context ".bulk" do
    it "can assign users to a group by email or username" do
      group = Fabricate(:group, name: "test", primary_group: true, title: 'WAT', grant_trust_level: 3)
      user = Fabricate(:user, trust_level: 2)
      user2 = Fabricate(:user, trust_level: 4)

      put :bulk_perform, params: {
        group_id: group.id, users: [user.username.upcase, user2.email, 'doesnt_exist']
      }, format: :json

      expect(response).to be_success

      user.reload
      expect(user.primary_group).to eq(group)
      expect(user.title).to eq("WAT")
      expect(user.trust_level).to eq(3)

      user2.reload
      expect(user2.primary_group).to eq(group)
      expect(user2.title).to eq("WAT")
      expect(user2.trust_level).to eq(4)

      # verify JSON response
      json = ::JSON.parse(response.body)
      expect(json['message']).to eq("2 users have been added to the group.")
      expect(json['users_not_added'][0]).to eq("doesnt_exist")
    end
  end

  context "#update" do
    it 'should update a group' do
      group.add_owner(user)

      expect do
        put :update, params: {
          id: group.id,
          group: {
            visibility_level: Group.visibility_levels[:owners],
            allow_membership_requests: "true"
          }
        }, format: :json

      end.to change { GroupHistory.count }.by(2)

      expect(response).to be_success

      group.reload

      expect(group.visibility_level).to eq(Group.visibility_levels[:owners])
      expect(group.allow_membership_requests).to eq(true)
    end

    it "ignore name change on automatic group" do
      put :update, params: { id: 1, group: { name: "WAT" } }, format: :json
      expect(response).to be_success

      group = Group.find(1)
      expect(group.name).not_to eq("WAT")
    end

    it "doesn't launch the 'automatic group membership' job when it's not retroactive" do
      Jobs.expects(:enqueue).never
      group = Fabricate(:group)

      put :update, params: {
        id: group.id, group: { automatic_membership_retroactive: "false" }
      }, format: :json

      expect(response).to be_success
    end

    it "launches the 'automatic group membership' job when it's retroactive" do
      group = Fabricate(:group)
      Jobs.expects(:enqueue).with(:automatic_group_membership, group_id: group.id)

      put :update, params: {
        id: group.id, group: { automatic_membership_retroactive: "true" }
      }, format: :json

      expect(response).to be_success
    end

  end

  context ".destroy" do

    it "returns a 422 if the group is automatic" do
      group = Fabricate(:group, automatic: true)
      delete :destroy, params: { id: group.id }, format: :json
      expect(response.status).to eq(422)
      expect(Group.where(id: group.id).count).to eq(1)
    end

    it "is able to destroy a non-automatic group" do
      group = Fabricate(:group)
      delete :destroy, params: { id: group.id }, format: :json
      expect(response.status).to eq(200)
      expect(Group.where(id: group.id).count).to eq(0)
    end

  end

  context ".refresh_automatic_groups" do

    it "is able to refresh automatic groups" do
      Group.expects(:refresh_automatic_groups!).returns(true)

      post :refresh_automatic_groups, format: :json
      expect(response.status).to eq(200)
    end

  end

end
