require 'rails_helper'

describe "Groups" do
  let(:user) { Fabricate(:user) }
  let(:group) { Fabricate(:group, users: [user]) }

  def sign_in(user)
    password = 'somecomplicatedpassword'
    user.update!(password: password)
    Fabricate(:email_token, confirmed: true, user: user)
    post "/session.json", { login: user.username, password: password }
    expect(response).to be_success
  end

  describe "checking if a group can be mentioned" do
    it "should return the right response" do
      sign_in(user)
      group.update_attributes!(name: 'test')

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
    let(:group) { Fabricate(:group, name: 'test', users: [user], public: false) }

    before do
      sign_in(user)
    end

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
          title: 'awesome team',
          public: true
        } }

        expect(response).to be_success

        group.reload

        expect(group.flair_bg_color).to eq('FFF')
        expect(group.flair_color).to eq('BBB')
        expect(group.flair_url).to eq('fa-adjust')
        expect(group.bio_raw).to eq('testing')
        expect(group.title).to eq('awesome team')
        expect(group.public).to eq(true)
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
      xhr :get, "/groups/#{group.name}/members", order: 'last_seen_at', desc: true

      expect(response).to be_success

      members = JSON.parse(response.body)["members"]

      expect(members.map { |m| m["id"] }).to eq([user1.id, user2.id])

      xhr :get, "/groups/#{group.name}/members", order: 'last_seen_at'

      expect(response).to be_success

      members = JSON.parse(response.body)["members"]

      expect(members.map { |m| m["id"] }).to eq([user2.id, user1.id])

      xhr :get, "/groups/#{group.name}/members", order: 'last_posted_at', desc: true

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

  describe "membership edit permissions" do
    let(:group) { Fabricate(:group) }

    context 'when user is not signed in' do
      it 'should be fobidden' do
        xhr :put, "/groups/#{group.id}/members", usernames: "bob"
        expect(response).to be_forbidden

        xhr :delete, "/groups/#{group.id}/members", username: "bob"
        expect(response).to be_forbidden
      end

      context 'public group' do
        it 'should be fobidden' do
          group.update_attributes!(public: true)

          expect { xhr :put, "/groups/#{group.id}/members", usernames: "bob" }
            .to raise_error(Discourse::NotLoggedIn)

          expect { xhr :delete, "/groups/#{group.id}/members", username: "bob" }
            .to raise_error(Discourse::NotLoggedIn)
        end
      end
    end

    context 'when user is not an owner of the group' do
      before do
        sign_in(user)
      end

      it "refuses membership changes to unauthorized users" do
        xhr :put, "/groups/#{group.id}/members", usernames: "bob"
        expect(response).to be_forbidden

        xhr :delete, "/groups/#{group.id}/members", username: "bob"
        expect(response).to be_forbidden
      end
    end

    context 'when user is an admin' do
      let(:user) { Fabricate(:admin) }
      let(:group) { Fabricate(:group, users: [user], automatic: true) }

      before do
        sign_in(user)
      end

      it "cannot add members to automatic groups" do
        xhr :put, "/groups/#{group.id}/members", usernames: "bob"
        expect(response).to be_forbidden

        xhr :delete, "/groups/#{group.id}/members", username: "bob"
        expect(response).to be_forbidden
      end
    end
  end

  describe "membership edits" do
    let(:admin) { Fabricate(:admin) }

    before do
      sign_in(admin)
    end

    context 'adding members' do
      it "can make incremental adds" do
        user2 = Fabricate(:user)
        expect(group.users.count).to eq(1)

        xhr :put, "/groups/#{group.id}/members", usernames: user2.username

        expect(response).to be_success
        expect(group.reload.users.count).to eq(2)
      end

      it "can make incremental deletes" do
        expect(group.users.count).to eq(1)

        xhr :delete, "/groups/#{group.id}/members", username: user.username

        expect(response).to be_success
        expect(group.reload.users.count).to eq(0)
      end

      it "cannot add members to automatic groups" do
        group.update!(automatic: true)

        xhr :put, "/groups/#{group.id}/members", usernames: "l77t"
        expect(response.status).to eq(403)
      end

      context "is able to add several members to a group" do
        let(:user1) { Fabricate(:user) }
        let(:user2) { Fabricate(:user) }

        it "adds by username" do
          expect { xhr :put, "/groups/#{group.id}/members", usernames: [user1.username, user2.username].join(",") }
            .to change { group.users.count }.by(2)

          expect(response).to be_success
        end

        it "adds by id" do
          expect { xhr :put, "/groups/#{group.id}/members", user_ids: [user1.id, user2.id].join(",") }
            .to change { group.users.count }.by(2)

          expect(response).to be_success
        end
      end

      it "returns 422 if member already exists" do
        xhr :put, "/groups/#{group.id}/members", usernames: user.username

        expect(response.status).to eq(422)
      end

      it "returns 404 if member is not found" do
        xhr :put, "/groups/#{group.id}/members", usernames: 'some donkey'

        expect(response.status).to eq(404)
      end

      context 'public group' do
        let(:other_user) { Fabricate(:user) }

        before do
          group.update!(public: true)
        end

        it 'should allow a user to join the group' do
          sign_in(other_user)

          expect { xhr :put, "/groups/#{group.id}/members", usernames: other_user.username }
            .to change { group.users.count }.by(1)

          expect(response).to be_success
        end

        it 'should not allow a user to add another user to a group' do
          xhr :put, "/groups/#{group.id}/members", usernames: other_user.username

          expect(response).to be_forbidden
        end
      end
    end

    context 'removing members' do
      it "cannot remove members from automatic groups" do
        group.update!(automatic: true)

        xhr :delete, "/groups/#{group.id}/members", user_id: 42
        expect(response.status).to eq(403)
      end

      it "raises an error if user to be removed is not found" do
        xhr :delete, "/groups/#{group.id}/members", user_id: -10
        expect(response.status).to eq(404)
      end

      context "is able to remove a member" do
        it "removes by id" do
          expect { xhr :delete, "/groups/#{group.id}/members", user_id: user.id }
            .to change { group.users.count }.by(-1)

          expect(response).to be_success
        end

        it "removes by username" do
          expect { xhr :delete, "/groups/#{group.id}/members", username: user.username }
            .to change { group.users.count }.by(-1)

          expect(response).to be_success
        end

        it "removes user.primary_group_id when user is removed from group" do
          user.update!(primary_group_id: group.id)

          xhr :delete, "/groups/#{group.id}/members", user_id: user.id

          expect(user.reload.primary_group_id).to eq(nil)
        end

        it "removes by user_email" do
          expect { xhr :delete, "/groups/#{group.id}/members", user_email: user.email }
            .to change { group.users.count }.by(-1)

          expect(response).to be_success
        end

        context 'public group' do
          let(:other_user) { Fabricate(:user) }
          let(:group) { Fabricate(:group, users: [other_user]) }

          before do
            group.update!(public: true)
          end

          it 'should allow a user to leave a group' do
            sign_in(other_user)

            expect { xhr :delete, "/groups/#{group.id}/members", username: other_user.username }
              .to change { group.users.count }.by(-1)

            expect(response).to be_success
          end

          it 'should not allow a user to leave a group for another user' do
            xhr :delete, "/groups/#{group.id}/members", username: other_user.username

            expect(response).to be_forbidden
          end
        end
      end
    end
  end
end
