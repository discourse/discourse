require 'rails_helper'

describe GroupsController do
  let(:user) { Fabricate(:user) }
  let(:group) { Fabricate(:group, users: [user]) }

  describe '#index' do
    let!(:staff_group) do
      Fabricate(:group, name: '0000', visibility_level: Group.visibility_levels[:staff])
    end

    context 'when group directory is disabled' do
      it 'should deny access' do
        SiteSetting.enable_group_directory = false

        get "/groups.json"
        expect(response).to be_forbidden
      end
    end

    it 'should return the right response' do
      group
      get "/groups.json"

      expect(response).to be_success

      response_body = JSON.parse(response.body)

      group_ids = response_body["groups"].map { |g| g["id"] }

      expect(response_body["extras"]["group_user_ids"]).to eq([])
      expect(group_ids).to include(group.id)
      expect(group_ids).to_not include(staff_group.id)
      expect(response_body["load_more_groups"]).to eq("/groups?page=1")
      expect(response_body["total_rows_groups"]).to eq(1)
    end

    context 'viewing as an admin' do
      it 'should display automatic groups' do
        admin = Fabricate(:admin)
        sign_in(admin)
        group.add(admin)

        get "/groups.json"

        expect(response).to be_success

        response_body = JSON.parse(response.body)

        group_ids = response_body["groups"].map { |g| g["id"] }

        expect(response_body["extras"]["group_user_ids"]).to eq([group.id])
        expect(group_ids).to include(group.id, staff_group.id)
        expect(response_body["load_more_groups"]).to eq("/groups?page=1")
        expect(response_body["total_rows_groups"]).to eq(10)
      end
    end
  end

  describe '#mentionable' do
    it "should return the right response" do
      sign_in(user)
      group.update_attributes!(name: 'test')

      get "/groups/test/mentionable.json", params: { name: group.name }

      expect(response).to be_success

      response_body = JSON.parse(response.body)
      expect(response_body["mentionable"]).to eq(false)

      group.update_attributes!(mentionable_level: Group::ALIAS_LEVELS[:everyone])

      get "/groups/test/mentionable.json", params: { name: group.name }
      expect(response).to be_success

      response_body = JSON.parse(response.body)
      expect(response_body["mentionable"]).to eq(true)
    end
  end

  describe '#update' do
    let(:group) do
      Fabricate(:group,
        name: 'test',
        users: [user],
        public_admission: false,
        public_exit: false
      )
    end

    before do
      sign_in(user)
    end

    context "when user is group owner" do
      before do
        group.add_owner(user)
        sign_in(user)
      end

      it "should be able update the group" do
        group.update!(allow_membership_requests: false)

        expect do
          put "/groups/#{group.id}.json", params: {
            group: {
              flair_bg_color: 'FFF',
              flair_color: 'BBB',
              flair_url: 'fa-adjust',
              bio_raw: 'testing',
              full_name: 'awesome team',
              public_admission: true,
              public_exit: true,
              allow_membership_requests: true
            }
          }
        end.to change { GroupHistory.count }.by(8)

        expect(response).to be_success

        group.reload

        expect(group.flair_bg_color).to eq('FFF')
        expect(group.flair_color).to eq('BBB')
        expect(group.flair_url).to eq('fa-adjust')
        expect(group.bio_raw).to eq('testing')
        expect(group.full_name).to eq('awesome team')
        expect(group.public_admission).to eq(true)
        expect(group.public_exit).to eq(true)
        expect(group.allow_membership_requests).to eq(true)
        expect(GroupHistory.last.subject).to eq('allow_membership_requests')
      end
    end

    context "when user is group admin" do
      before do
        user.update_attributes!(admin: true)
        sign_in(user)
      end

      it 'should be able to update the group' do
        put "/groups/#{group.id}.json", params: { group: { flair_color: 'BBB' } }

        expect(response).to be_success
        expect(group.reload.flair_color).to eq('BBB')
      end
    end

    context "when user is not a group owner or admin" do
      it 'should not be able to update the group' do
        sign_in(user)

        put "/groups/#{group.id}.json", params: { group: { name: 'testing' } }

        expect(response.status).to eq(403)
      end
    end
  end

  describe '#members' do
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

    let(:user3) do
      Fabricate(:user,
        last_seen_at: nil,
        last_posted_at: nil,
        email: 'c@test.org'
      )
    end

    let(:bot) { Fabricate(:user, id: -999) }

    let(:group) { Fabricate(:group, users: [user1, user2, user3, bot]) }

    it "should allow members to be sorted by" do
      get "/groups/#{group.name}/members.json", params: {
        order: 'last_seen_at', desc: true
      }

      expect(response).to be_success

      members = JSON.parse(response.body)["members"]

      expect(members.map { |m| m["id"] }).to eq([user1.id, user2.id, user3.id])

      get "/groups/#{group.name}/members.json", params: { order: 'last_seen_at' }

      expect(response).to be_success

      members = JSON.parse(response.body)["members"]

      expect(members.map { |m| m["id"] }).to eq([user2.id, user1.id, user3.id])

      get "/groups/#{group.name}/members.json", params: {
        order: 'last_posted_at', desc: true
      }

      expect(response).to be_success

      members = JSON.parse(response.body)["members"]

      expect(members.map { |m| m["id"] }).to eq([user2.id, user1.id, user3.id])
    end

    it "should not allow members to be sorted by columns that are not allowed" do
      get "/groups/#{group.name}/members.json", params: { order: 'email' }

      expect(response).to be_success

      members = JSON.parse(response.body)["members"]

      expect(members.map { |m| m["id"] }).to eq([user1.id, user2.id, user3.id])
    end
  end

  describe "edit" do
    let(:group) { Fabricate(:group) }

    context 'when user is not signed in' do
      it 'should be fobidden' do
        put "/groups/#{group.id}/members.json", params: { usernames: "bob" }
        expect(response).to be_forbidden

        delete "/groups/#{group.id}/members.json", params: { username: "bob" }
        expect(response).to be_forbidden
      end

      context 'public group' do
        it 'should be fobidden' do
          group.update_attributes!(
            public_admission: true,
            public_exit: true
          )

          expect { put "/groups/#{group.id}/members.json", params: { usernames: "bob" } }
            .to raise_error(Discourse::NotLoggedIn)

          expect { delete "/groups/#{group.id}/members.json", params: { username: "bob" } }
            .to raise_error(Discourse::NotLoggedIn)
        end
      end
    end

    context 'when user is not an owner of the group' do
      before do
        sign_in(user)
      end

      it "refuses membership changes to unauthorized users" do
        put "/groups/#{group.id}/members.json", params: { usernames: "bob" }
        expect(response).to be_forbidden

        delete "/groups/#{group.id}/members.json", params: { username: "bob" }
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
        put "/groups/#{group.id}/members.json", params: { usernames: "bob" }
        expect(response).to be_forbidden

        delete "/groups/#{group.id}/members.json", params: { username: "bob" }
        expect(response).to be_forbidden
      end
    end
  end

  describe "membership edits" do
    let(:admin) { Fabricate(:admin) }

    before do
      sign_in(admin)
    end

    context 'add_members' do
      it "can make incremental adds" do
        user2 = Fabricate(:user)

        expect do
          put "/groups/#{group.id}/members.json", params: { usernames: user2.username }
        end.to change { group.users.count }.by(1)

        expect(response).to be_success

        group_history = GroupHistory.last

        expect(group_history.action).to eq(GroupHistory.actions[:add_user_to_group])
        expect(group_history.acting_user).to eq(admin)
        expect(group_history.target_user).to eq(user2)
      end

      it "cannot add members to automatic groups" do
        group.update!(automatic: true)

        put "/groups/#{group.id}/members.json", params: { usernames: "l77t" }
        expect(response.status).to eq(403)
      end

      context "is able to add several members to a group" do
        let(:user1) { Fabricate(:user) }
        let(:user2) { Fabricate(:user) }

        it "adds by username" do
          expect do
            put "/groups/#{group.id}/members.json",
              params: { usernames: [user1.username, user2.username].join(",") }
          end.to change { group.users.count }.by(2)

          expect(response).to be_success
        end

        it "adds by id" do
          expect do
            put "/groups/#{group.id}/members.json",
              params: { user_ids: [user1.id, user2.id].join(",") }
          end.to change { group.users.count }.by(2)

          expect(response).to be_success
        end

        it "adds by email" do
          expect do
            put "/groups/#{group.id}/members.json",
              params: { user_emails: [user1.email, user2.email].join(",") }
          end.to change { group.users.count }.by(2)

          expect(response).to be_success
        end
      end

      it "returns 422 if member already exists" do
        put "/groups/#{group.id}/members.json", params: { usernames: user.username }

        expect(response.status).to eq(422)
      end

      it "returns 404 if member is not found" do
        put "/groups/#{group.id}/members.json", params: { usernames: 'some donkey' }

        expect(response.status).to eq(404)
      end

      context 'public group' do
        let(:other_user) { Fabricate(:user) }

        before do
          group.update!(
            public_admission: true,
            public_exit: true
          )
        end

        context 'admin' do
          it "can make incremental adds" do
            expect do
              put "/groups/#{group.id}/members.json",
                params: { usernames: other_user.username }
            end.to change { group.users.count }.by(1)

            expect(response).to be_success

            group_history = GroupHistory.last

            expect(group_history.action).to eq(GroupHistory.actions[:add_user_to_group])
            expect(group_history.acting_user).to eq(admin)
            expect(group_history.target_user).to eq(other_user)
          end
        end

        it 'should allow a user to join the group' do
          sign_in(other_user)

          expect do
            put "/groups/#{group.id}/members.json",
              params: { usernames: other_user.username }
          end.to change { group.users.count }.by(1)

          expect(response).to be_success
        end

        it 'should not allow an underprivilege user to add another user to a group' do
          sign_in(user)

          put "/groups/#{group.id}/members.json",
            params: { usernames: other_user.username }

          expect(response).to be_forbidden
        end
      end
    end

    context '#remove_member' do
      it "cannot remove members from automatic groups" do
        group.update!(automatic: true)

        delete "/groups/#{group.id}/members.json", params: { user_id: 42 }
        expect(response.status).to eq(403)
      end

      it "raises an error if user to be removed is not found" do
        delete "/groups/#{group.id}/members.json", params: { user_id: -10 }
        expect(response.status).to eq(404)
      end

      context "is able to remove a member" do
        it "removes by id" do
          expect do
            delete "/groups/#{group.id}/members.json", params: { user_id: user.id }
          end.to change { group.users.count }.by(-1)

          expect(response).to be_success
        end

        it "removes by username" do
          expect do
            delete "/groups/#{group.id}/members.json", params: { username: user.username }
          end.to change { group.users.count }.by(-1)

          expect(response).to be_success
        end

        it "removes user.primary_group_id when user is removed from group" do
          user.update!(primary_group_id: group.id)

          delete "/groups/#{group.id}/members.json", params: { user_id: user.id }

          expect(user.reload.primary_group_id).to eq(nil)
        end

        it "removes by user_email" do
          expect do
            delete "/groups/#{group.id}/members.json",
              params: { user_email: user.email }
          end.to change { group.users.count }.by(-1)

          expect(response).to be_success
        end

        context 'public group' do
          let(:other_user) { Fabricate(:user) }
          let(:group) { Fabricate(:public_group, users: [other_user]) }

          context "admin" do
            it "removes by username" do
              expect do
                delete "/groups/#{group.id}/members.json",
                  params: { username: other_user.username }
              end.to change { group.users.count }.by(-1)

              expect(response).to be_success
            end
          end

          it 'should allow a user to leave a group' do
            sign_in(other_user)

            expect do
              delete "/groups/#{group.id}/members.json",
              params: { username: other_user.username }
            end.to change { group.users.count }.by(-1)

            expect(response).to be_success
          end

          it 'should not allow a underprivilege user to leave a group for another user' do
            sign_in(user)

            delete "/groups/#{group.id}/members.json",
              params: { username: other_user.username }

            expect(response).to be_forbidden
          end
        end
      end
    end
  end

  describe "group histories" do
    context 'when user is not signed in' do
      it 'should raise the right error' do
        expect do
          get "/groups/#{group.name}/logs.json"
        end.to raise_error(Discourse::NotLoggedIn)
      end
    end

    context 'when user is not a group owner' do
      before do
        sign_in(user)
      end

      it 'should be forbidden' do
        get "/groups/#{group.name}/logs.json"

        expect(response).to be_forbidden
      end
    end

    describe 'viewing history' do
      context 'public group' do
        before do
          group.add_owner(user)

          group.update_attributes!(
            public_admission: true,
            public_exit: true
          )

          GroupActionLogger.new(user, group).log_change_group_settings
          sign_in(user)
        end

        it 'should allow group owner to view history' do
          get "/groups/#{group.name}/logs.json"

          expect(response).to be_success

          result = JSON.parse(response.body)["logs"].last

          expect(result["action"]).to eq(GroupHistory.actions[1].to_s)
          expect(result["subject"]).to eq('public_exit')
          expect(result["prev_value"]).to eq('f')
          expect(result["new_value"]).to eq('t')
        end
      end

      context 'admin' do
        let(:admin) { Fabricate(:admin) }

        before do
          sign_in(admin)
        end

        it 'should be able to view history' do
          GroupActionLogger.new(admin, group).log_remove_user_from_group(user)

          get "/groups/#{group.name}/logs.json"

          expect(response).to be_success

          result = JSON.parse(response.body)["logs"].first

          expect(result["action"]).to eq(GroupHistory.actions[3].to_s)
        end

        it 'should be able to filter through the history' do
          GroupActionLogger.new(admin, group).log_add_user_to_group(user)
          GroupActionLogger.new(admin, group).log_remove_user_from_group(user)

          get "/groups/#{group.name}/logs.json", params: {
            filters: { "action" => "add_user_to_group" }
          }

          expect(response).to be_success

          logs = JSON.parse(response.body)["logs"]

          expect(logs.count).to eq(1)
          expect(logs.first["action"]).to eq(GroupHistory.actions[2].to_s)
        end
      end
    end
  end

  describe '#request_membership' do
    let(:new_user) { Fabricate(:user) }

    it 'requires the user to log in' do
      expect do
        post "/groups/#{group.name}/request_membership.json"
      end.to raise_error(Discourse::NotLoggedIn)
    end

    it 'requires a reason' do
      sign_in(user)

      expect do
        post "/groups/#{group.name}/request_membership.json"
      end.to raise_error(ActionController::ParameterMissing)
    end

    it 'should create the right PM' do
      owner1 = Fabricate(:user, last_seen_at: Time.zone.now)
      owner2 = Fabricate(:user, last_seen_at: Time.zone.now - 1 .day)
      [owner1, owner2].each { |owner| group.add_owner(owner) }

      sign_in(user)

      post "/groups/#{group.name}/request_membership.json",
        params: { reason: 'Please add me in' }

      expect(response).to be_success

      post = Post.last
      topic = post.topic
      body = JSON.parse(response.body)

      expect(body['relative_url']).to eq(topic.relative_url)
      expect(post.user).to eq(user)

      expect(topic.title).to eq(I18n.t('groups.request_membership_pm.title',
        group_name: group.name
      ))

      expect(post.raw).to eq('Please add me in')
      expect(topic.archetype).to eq(Archetype.private_message)
      expect(topic.allowed_users).to contain_exactly(user, owner1, owner2)
      expect(topic.allowed_groups).to eq([])
    end
  end

  describe '#search ' do
    let(:hidden_group) do
      Fabricate(:group,
        visibility_level: Group.visibility_levels[:owners],
        name: 'KingOfTheNorth'
      )
    end

    before do
      group.update!(
        name: 'GOT',
        full_name: 'Daenerys Targaryen'
      )

      hidden_group
    end

    context 'as an anon user' do
      it "returns the right response" do
        expect do
          get '/groups/search.json'
        end.to raise_error(Discourse::NotLoggedIn)
      end
    end

    context 'as a normal user' do
      it "returns the right response" do
        sign_in(user)

        get '/groups/search.json'

        expect(response).to be_success
        groups = JSON.parse(response.body)

        expected_ids = Group::AUTO_GROUPS.map { |name, id| id }
        expected_ids.delete(Group::AUTO_GROUPS[:everyone])
        expected_ids << group.id

        expect(groups.map { |group| group["id"] }).to contain_exactly(*expected_ids)

        ['GO', 'nerys'].each do |term|
          get "/groups/search.json?term=#{term}"

          expect(response).to be_success
          groups = JSON.parse(response.body)

          expect(groups.length).to eq(1)
          expect(groups.first['id']).to eq(group.id)
        end

        get "/groups/search.json?term=KingOfTheNorth"

        expect(response).to be_success
        groups = JSON.parse(response.body)

        expect(groups).to eq([])
      end
    end

    context 'as a group owner' do
      before do
        hidden_group.add_owner(user)
      end

      it "returns the right response" do
        sign_in(user)

        get "/groups/search.json?term=north"

        expect(response).to be_success
        groups = JSON.parse(response.body)

        expect(groups.length).to eq(1)
        expect(groups.first['id']).to eq(hidden_group.id)
      end
    end

    context 'as an admin' do
      it "returns the right response" do
        sign_in(Fabricate(:admin))

        get '/groups/search.json?ignore_automatic=true'

        expect(response).to be_success
        groups = JSON.parse(response.body)

        expect(groups.length).to eq(2)

        expect(groups.map { |group| group['id'] })
          .to contain_exactly(group.id, hidden_group.id)
      end
    end
  end
end
