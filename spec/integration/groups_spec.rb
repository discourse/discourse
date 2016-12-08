require 'rails_helper'

describe "Groups" do
  let(:user) { Fabricate(:user) }

  def sign_in(user)
    password = 'somecomplicatedpassword'
    user.update!(password: password)
    Fabricate(:email_token, confirmed: true, user: user)
    post "/session.json", { login: user.username, password: password }
    expect(response).to be_success
  end

  describe "checking if a group can be mentioned" do
    let(:group) { Fabricate(:group, name: 'test', users: [user]) }

    it "should return the right response" do
      sign_in(user)
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
        sign_in(user)
      end

      it "should be able update the group" do
        xhr :put, "/groups/#{group.id}", { group: {
          flair_bg_color: 'FFF',
          flair_color: 'BBB',
          flair_url: 'fa-adjust',
          bio_raw: 'testing',
          title: 'awesome team'
        } }

        expect(response).to be_success

        group.reload

        expect(group.flair_bg_color).to eq('FFF')
        expect(group.flair_color).to eq('BBB')
        expect(group.flair_url).to eq('fa-adjust')
        expect(group.bio_raw).to eq('testing')
        expect(group.title).to eq('awesome team')
      end
    end

    context "when user is group admin" do
      before do
        user.update_attributes!(admin: true)
        sign_in(user)
      end

      it 'should be able to update the group' do
        xhr :put, "/groups/#{group.id}", { group: { flair_color: 'BBB' } }

        expect(response).to be_success
        expect(group.reload.flair_color).to eq('BBB')
      end
    end

    context "when user is not a group owner or admin" do
      it 'should not be able to update the group' do
        sign_in(user)

        xhr :put, "/groups/#{group.id}", { group: { name: 'testing' } }

        expect(response.status).to eq(403)
      end
    end
  end

  describe 'members' do
    let(:user1) do
      Fabricate(:user,
        last_seen_at: Time.zone.now,
        last_posted_at: Time.zone.now - 1.day,
        email: 'b@test.org'
      )
    end

    let(:user2) do
      Fabricate(:user,
        last_seen_at: Time.zone.now - 1 .day,
        last_posted_at: Time.zone.now,
        email: 'a@test.org'
      )
    end

    let(:group) { Fabricate(:group, users: [user1, user2]) }

    it "should allow members to be sorted by" do
      xhr :get, "/groups/#{group.name}/members", order: 'last_seen_at', asc: true

      expect(response).to be_success

      members = JSON.parse(response.body)["members"]

      expect(members.map { |m| m["id"] }).to eq([user1.id, user2.id])

      xhr :get, "/groups/#{group.name}/members", order: 'last_seen_at'

      expect(response).to be_success

      members = JSON.parse(response.body)["members"]

      expect(members.map { |m| m["id"] }).to eq([user2.id, user1.id])

      xhr :get, "/groups/#{group.name}/members", order: 'last_posted_at', asc: true

      expect(response).to be_success

      members = JSON.parse(response.body)["members"]

      expect(members.map { |m| m["id"] }).to eq([user2.id, user1.id])
    end

    it "should not allow members to be sorted by columns that are not allowed" do
      xhr :get, "/groups/#{group.name}/members", order: 'email'

      expect(response).to be_success

      members = JSON.parse(response.body)["members"]

      expect(members.map { |m| m["id"] }).to eq([user1.id, user2.id])
    end
  end
end
