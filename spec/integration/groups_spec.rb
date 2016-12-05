require 'rails_helper'

describe "Groups" do
  let(:password) { 'somecomplicatedpassword' }
  let(:email_token) { Fabricate(:email_token, confirmed: true) }
  let(:user) { email_token.user }

  before do
    user.update_attributes!(password: password)
    post "/session.json", { login: user.username, password: password }
    expect(response).to be_success
  end

  describe "checking if a group can be mentioned" do
    let(:group) { Fabricate(:group, name: 'test', users: [user]) }

    it "should return the right response" do
      group

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

  describe "group can be updated" do
    let(:group) { Fabricate(:group, name: 'test', users: [user]) }

    context "when user is group owner" do
      before do
        group.add_owner(user)
      end

      it "should be able update the group" do
        xhr :put, "/groups/#{group.id}", { group: {
          flair_bg_color: 'FFF',
          flair_color: 'BBB',
          flair_url: 'fa-adjust',
          bio_raw: 'testing'
        } }

        expect(response).to be_success

        group.reload

        expect(group.flair_bg_color).to eq('FFF')
        expect(group.flair_color).to eq('BBB')
        expect(group.flair_url).to eq('fa-adjust')
        expect(group.bio_raw).to eq('testing')
      end
    end

    context "when user is group admin" do
      before do
        user.update_attributes!(admin: true)
      end

      it 'should be able to update the group' do
        xhr :put, "/groups/#{group.id}", { group: { flair_color: 'BBB' } }

        expect(response).to be_success
        expect(group.reload.flair_color).to eq('BBB')
      end
    end

    context "when user is not a group owner or admin" do
      it 'should not be able to update the group' do
        xhr :put, "/groups/#{group.id}", { group: { name: 'testing' } }

        expect(response.status).to eq(403)
      end
    end
  end
end
