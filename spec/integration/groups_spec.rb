require 'rails_helper'

describe "Groups" do
  describe "checking if a group can be mentioned" do
    let(:password) { 'somecomplicatedpassword' }
    let(:email_token) { Fabricate(:email_token, confirmed: true) }
    let(:user) { email_token.user }
    let(:group) { Fabricate(:group, name: 'test', users: [user]) }

    before do
      user.update_attributes!(password: password)
    end

    it "should return the right response" do
      group

      post "/session.json", { login: user.username, password: password }
      expect(response).to be_success

      get "/groups/test/mentionable.json", { name: group.name }

      expect(response).to be_success

      response_body = JSON.parse(response.body)
      expect(response_body["mentionable"]).to eq(false)

      group.update_attributes!(alias_level: Group::ALIAS_LEVELS[:everyone])

      get "/groups/test/mentionable.json", { name: group.name }
      expect(response).to be_success

      response_body = JSON.parse(response.body)
      expect(response_body["mentionable"]).to eq(true)
    end
  end
end
