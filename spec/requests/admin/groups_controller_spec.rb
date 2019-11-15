# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::GroupsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }

  before do
    sign_in(admin)
  end

  describe '#create' do
    let(:group_params) do
      {
        group: {
          name: 'testing',
          usernames: [admin.username, user.username].join(","),
          owner_usernames: [user.username].join(","),
          allow_membership_requests: true,
          membership_request_template: 'Testing',
          members_visibility_level: Group.visibility_levels[:staff]
        }
      }
    end

    it 'should work' do
      post "/admin/groups.json", params: group_params

      expect(response.status).to eq(200)

      group = Group.last

      expect(group.name).to eq('testing')
      expect(group.users).to contain_exactly(admin, user)
      expect(group.allow_membership_requests).to eq(true)
      expect(group.membership_request_template).to eq('Testing')
      expect(group.members_visibility_level).to eq(Group.visibility_levels[:staff])
    end

    context "custom_fields" do
      before do
        plugin = Plugin::Instance.new
        plugin.register_editable_group_custom_field :test
      end

      after do
        Group.plugin_editable_group_custom_fields.clear
      end

      it "only updates allowed user fields" do
        params = group_params
        params[:group].merge!(custom_fields: { test: :hello1, test2: :hello2 })

        post "/admin/groups.json", params: params

        group = Group.last

        expect(response.status).to eq(200)
        expect(group.custom_fields['test']).to eq('hello1')
        expect(group.custom_fields['test2']).to be_blank
      end

      it "is secure when there are no registered editable fields" do
        Group.plugin_editable_group_custom_fields.clear
        params = group_params
        params[:group].merge!(custom_fields: { test: :hello1, test2: :hello2 })

        post "/admin/groups.json", params: params

        group = Group.last

        expect(response.status).to eq(200)
        expect(group.custom_fields['test']).to be_blank
        expect(group.custom_fields['test2']).to be_blank
      end
    end
  end

  describe '#add_owners' do
    it 'should work' do
      put "/admin/groups/#{group.id}/owners.json", params: {
        group: {
          usernames: [user.username, admin.username].join(",")
        }
      }

      expect(response.status).to eq(200)

      response_body = JSON.parse(response.body)

      expect(response_body["usernames"]).to contain_exactly(user.username, admin.username)

      expect(group.group_users.where(owner: true).map(&:user))
        .to contain_exactly(user, admin)
    end
  end

  describe '#remove_owner' do
    it 'should work' do
      group.add_owner(user)

      delete "/admin/groups/#{group.id}/owners.json", params: {
        user_id: user.id
      }

      expect(response.status).to eq(200)
      expect(group.group_users.where(owner: true)).to eq([])
    end
  end

  describe "#bulk_perform" do
    fab!(:group) do
      Fabricate(:group,
        name: "test",
        primary_group: true,
        title: 'WAT',
        grant_trust_level: 3
      )
    end

    fab!(:user) { Fabricate(:user, trust_level: 2) }
    fab!(:user2) { Fabricate(:user, trust_level: 4) }

    it "can assign users to a group by email or username" do
      Jobs.run_immediately!

      put "/admin/groups/bulk.json", params: {
        group_id: group.id, users: [user.username.upcase, user2.email, 'doesnt_exist']
      }

      expect(response.status).to eq(200)

      user.reload
      expect(user.primary_group).to eq(group)
      expect(user.title).to eq("WAT")
      expect(user.trust_level).to eq(3)

      user2.reload
      expect(user2.primary_group).to eq(group)
      expect(user2.title).to eq("WAT")
      expect(user2.trust_level).to eq(4)

      json = ::JSON.parse(response.body)
      expect(json['message']).to eq("2 users have been added to the group.")
      expect(json['users_not_added'][0]).to eq("doesnt_exist")
    end
  end

  context "#destroy" do
    it 'should return the right response for an invalid group_id' do
      max_id = Group.maximum(:id).to_i
      delete "/admin/groups/#{max_id + 1}.json"
      expect(response.status).to eq(404)
    end

    describe 'when group is automatic' do
      it "returns the right response" do
        group.update!(automatic: true)

        delete "/admin/groups/#{group.id}.json"

        expect(response.status).to eq(422)
        expect(Group.find(group.id)).to eq(group)
      end
    end

    describe 'for a non automatic group' do
      it "returns the right response" do
        delete "/admin/groups/#{group.id}.json"

        expect(response.status).to eq(200)
        expect(Group.find_by(id: group.id)).to eq(nil)
      end
    end
  end
end
