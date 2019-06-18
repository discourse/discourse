# encoding: UTF-8
# frozen_string_literal: true

require 'rails_helper'

describe 'invite only' do

  describe '#create invite only' do
    it 'can create user via API' do

      SiteSetting.invite_only = true
      Jobs.run_immediately!

      admin = Fabricate(:admin)
      api_key = Fabricate(:api_key, user: admin)

      post '/users.json', params: {
        name: 'bob',
        username: 'bob',
        password: 'strongpassword',
        email: 'bob@bob.com',
        api_key: api_key.key,
        api_username: admin.username
      }

      user_id = JSON.parse(response.body)["user_id"]
      expect(user_id).to be > 0

      # activate and approve
      put "/admin/users/#{user_id}/activate.json", params: {
        api_key: api_key.key,
        api_username: admin.username
      }

      put "/admin/users/#{user_id}/approve.json", params: {
        api_key: api_key.key,
        api_username: admin.username
      }

      u = User.find(user_id)
      expect(u.active).to eq(true)
      expect(u.approved).to eq(true)

    end
  end
end
