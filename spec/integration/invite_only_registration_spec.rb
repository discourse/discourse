# encoding: UTF-8
# frozen_string_literal: true

RSpec.describe "invite only" do
  describe "#create invite only" do
    it "can create user via API" do
      SiteSetting.invite_only = true
      SiteSetting.hide_email_address_taken = false
      Jobs.run_immediately!

      admin = Fabricate(:admin)
      api_key = Fabricate(:api_key, user: admin)

      post "/users.json",
           params: {
             name: "bob",
             username: "bob",
             password: "strongpassword",
             email: "bob@bob.com",
           },
           headers: {
             HTTP_API_KEY: api_key.key,
             HTTP_API_USERNAME: admin.username,
           }

      user_id = response.parsed_body["user_id"]
      expect(user_id).to be > 0

      # activate and approve
      put "/admin/users/#{user_id}/activate.json",
          headers: {
            HTTP_API_KEY: api_key.key,
            HTTP_API_USERNAME: admin.username,
          }

      put "/admin/users/#{user_id}/approve.json",
          headers: {
            HTTP_API_KEY: api_key.key,
            HTTP_API_USERNAME: admin.username,
          }

      u = User.find(user_id)
      expect(u.active).to eq(true)
      expect(u.approved).to eq(true)
    end
  end
end
