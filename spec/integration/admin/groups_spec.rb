require 'rails_helper'

RSpec.describe "Managing groups as an admin" do
  let(:admin) { Fabricate(:admin) }
  let(:user) { Fabricate(:user) }
  let(:group) { Fabricate(:group) }

  before do
    sign_in(admin)
  end

  describe 'creating a new group' do
    it 'should work' do
      post "/admin/groups.json", group: {
        name: 'testing',
        usernames: [admin.username, user.username].join(","),
        owner_usernames: [user.username].join(","),
        allow_membership_requests: true
      }

      expect(response).to be_success

      group = Group.last

      expect(group.name).to eq('testing')
      expect(group.users).to contain_exactly(admin, user)
      expect(group.allow_membership_requests).to eq(true)
    end
  end

  describe 'adding a new owner' do
    it 'should work' do
      put "/admin/groups/#{group.id}/owners.json", group: {
        usernames: [user.username, admin.username].join(",")
      }

      expect(response).to be_success

      expect(group.group_users.where(owner: true).map(&:user))
        .to contain_exactly(user, admin)
    end
  end
end
