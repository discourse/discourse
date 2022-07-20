# frozen_string_literal: true

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
        DiscoursePluginRegistry.reset!
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
        DiscoursePluginRegistry.reset!
        params = group_params
        params[:group].merge!(custom_fields: { test: :hello1, test2: :hello2 })

        post "/admin/groups.json", params: params

        group = Group.last

        expect(response.status).to eq(200)
        expect(group.custom_fields['test']).to be_blank
        expect(group.custom_fields['test2']).to be_blank
      end
    end

    context 'with Group.plugin_permitted_params' do
      after do
        DiscoursePluginRegistry.reset!
      end

      it 'filter unpermitted params' do
        params = group_params
        params[:group].merge!(allow_unknown_sender_topic_replies: true)

        post "/admin/groups.json", params: params
        expect(Group.last.allow_unknown_sender_topic_replies).to eq(false)
      end

      it 'allows plugin to allow custom params' do
        params = group_params
        params[:group].merge!(allow_unknown_sender_topic_replies: true)

        plugin = Plugin::Instance.new
        plugin.register_group_param :allow_unknown_sender_topic_replies

        post "/admin/groups.json", params: params
        expect(Group.last.allow_unknown_sender_topic_replies).to eq(true)
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

      response_body = response.parsed_body

      expect(response_body["usernames"]).to contain_exactly(user.username, admin.username)

      expect(group.group_users.where(owner: true).map(&:user))
        .to contain_exactly(user, admin)
    end

    it 'returns not-found error when there is no group' do
      group.destroy!

      put "/admin/groups/#{group.id}/owners.json", params: {
        group: {
          usernames: user.username
        }
      }

      expect(response.status).to eq(404)
    end

    it 'does not allow adding owners to an automatic group' do
      group.update!(automatic: true)

      expect do
        put "/admin/groups/#{group.id}/owners.json", params: {
          group: {
            usernames: user.username
          }
        }
      end.to_not change { group.group_users.count }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq(["You cannot modify an automatic group"])
    end

    it 'does not notify users when the param is not present' do
      put "/admin/groups/#{group.id}/owners.json", params: {
        group: {
          usernames: user.username
        }
      }
      expect(response.status).to eq(200)

      topic = Topic.find_by(
        title: I18n.t("system_messages.user_added_to_group_as_owner.subject_template", group_name: group.name),
        archetype: "private_message"
      )
      expect(topic.nil?).to eq(true)
    end

    it 'notifies users when the param is present' do
      put "/admin/groups/#{group.id}/owners.json", params: {
        group: {
          usernames: user.username,
          notify_users: true
        }
      }
      expect(response.status).to eq(200)

      topic = Topic.find_by(
        title: I18n.t("system_messages.user_added_to_group_as_owner.subject_template", group_name: group.name),
        archetype: "private_message"
      )
      expect(topic.nil?).to eq(false)
      expect(topic.topic_users.map(&:user_id)).to include(-1, user.id)
    end
  end

  describe '#remove_owner' do
    let(:user2) { Fabricate(:user) }
    let(:user3) { Fabricate(:user) }

    it 'should work' do
      group.add_owner(user)

      delete "/admin/groups/#{group.id}/owners.json", params: {
        user_id: user.id
      }

      expect(response.status).to eq(200)
      expect(group.group_users.where(owner: true)).to eq([])
    end

    it 'should work with multiple users' do
      group.add_owner(user)
      group.add_owner(user3)

      delete "/admin/groups/#{group.id}/owners.json", params: {
        group: {
          usernames: "#{user.username},#{user2.username},#{user3.username}"
        }
      }

      expect(response.status).to eq(200)
      expect(group.group_users.where(owner: true)).to eq([])
    end

    it 'returns not-found error when there is no group' do
      group.destroy!

      delete "/admin/groups/#{group.id}/owners.json", params: {
        user_id: user.id
      }

      expect(response.status).to eq(404)
    end

    it 'does not allow removing owners from an automatic group' do
      group.update!(automatic: true)

      delete "/admin/groups/#{group.id}/owners.json", params: {
        user_id: user.id
      }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq(["You cannot modify an automatic group"])
    end
  end

  describe "#set_primary" do
    let(:user2) { Fabricate(:user) }
    let(:user3) { Fabricate(:user) }

    it 'sets with multiple users' do
      user2.update!(primary_group_id: group.id)

      put "/admin/groups/#{group.id}/primary.json", params: {
        group: { usernames: "#{user.username},#{user2.username},#{user3.username}" },
        primary: "true"
      }

      expect(response.status).to eq(200)
      expect(User.where(primary_group_id: group.id).size).to eq(3)
    end

    it 'unsets with multiple users' do
      user.update!(primary_group_id: group.id)
      user3.update!(primary_group_id: group.id)

      put "/admin/groups/#{group.id}/primary.json", params: {
        group: { usernames: "#{user.username},#{user2.username},#{user3.username}" },
        primary: "false"
      }

      expect(response.status).to eq(200)
      expect(User.where(primary_group_id: group.id).size).to eq(0)
    end
  end

  context "#destroy" do
    it 'should return the right response for an invalid group_id' do
      max_id = Group.maximum(:id).to_i
      delete "/admin/groups/#{max_id + 1}.json"
      expect(response.status).to eq(404)
    end

    it 'logs when a group is destroyed' do
      delete "/admin/groups/#{group.id}.json"

      history = UserHistory.where(acting_user: admin).last

      expect(history).to be_present
      expect(history.details).to include("name: #{group.name}")
      expect(history.details).to include("id: #{group.id}")
    end

    it 'logs the grant_trust_level attribute' do
      trust_level = TrustLevel[4]
      group.update!(grant_trust_level: trust_level)
      delete "/admin/groups/#{group.id}.json"

      history = UserHistory.where(acting_user: admin).last

      expect(history).to be_present
      expect(history.details).to include("grant_trust_level: #{trust_level}")
      expect(history.details).to include("name: #{group.name}")
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

  describe '#automatic_membership_count' do
    it 'returns count of users whose emails match the domain' do
      Fabricate(:user, email: 'user1@somedomain.org')
      Fabricate(:user, email: 'user1@somedomain.com')
      Fabricate(:user, email: 'user1@notsomedomain.com')
      group = Fabricate(:group)

      put "/admin/groups/automatic_membership_count.json", params: {
        automatic_membership_email_domains: 'somedomain.org|somedomain.com',
        id: group.id
      }
      expect(response.status).to eq(200)
      expect(response.parsed_body["user_count"]).to eq(2)
    end

    it "doesn't responde with 500 if domain is invalid" do
      group = Fabricate(:group)

      put "/admin/groups/automatic_membership_count.json", params: {
        automatic_membership_email_domains: '@somedomain.org|@somedomain.com',
        id: group.id
      }
      expect(response.status).to eq(200)
      expect(response.parsed_body["user_count"]).to eq(0)
    end
  end

  context "when moderators_manage_categories_and_groups is enabled" do
    let(:group_params) do
      {
        group: {
          name: 'testing-as-moderator',
          usernames: [admin.username, user.username].join(","),
          owner_usernames: [user.username].join(","),
          allow_membership_requests: true,
          membership_request_template: 'Testing',
          members_visibility_level: Group.visibility_levels[:staff]
        }
      }
    end

    before do
      SiteSetting.moderators_manage_categories_and_groups = true
    end

    context "the user is a moderator" do
      before do
        user.update!(moderator: true)
        sign_in(user)
      end

      it 'should allow groups to be created' do
        post "/admin/groups.json", params: group_params

        expect(response.status).to eq(200)

        group = Group.last

        expect(group.name).to eq('testing-as-moderator')
        expect(group.users).to contain_exactly(admin, user)
        expect(group.allow_membership_requests).to eq(true)
        expect(group.membership_request_template).to eq('Testing')
        expect(group.members_visibility_level).to eq(Group.visibility_levels[:staff])
      end

      it 'should allow group owners to be added' do
        put "/admin/groups/#{group.id}/owners.json", params: {
          group: {
            usernames: [user.username, admin.username].join(",")
          }
        }

        expect(response.status).to eq(200)

        response_body = response.parsed_body

        expect(response_body["usernames"]).to contain_exactly(user.username, admin.username)

        expect(group.group_users.where(owner: true).map(&:user))
          .to contain_exactly(user, admin)
      end

      it 'should allow groups owners to be removed' do
        group.add_owner(user)

        delete "/admin/groups/#{group.id}/owners.json", params: {
          user_id: user.id
        }

        expect(response.status).to eq(200)
        expect(group.group_users.where(owner: true)).to eq([])
      end
    end

    context "the user is not a moderator or admin" do
      before do
        user.update!(moderator: false, admin: false)
        sign_in(user)
      end

      it 'should not allow groups to be created' do
        post "/admin/groups.json", params: group_params

        expect(response.status).to eq(404)
      end

      it 'should not allow group owners to be added' do
        put "/admin/groups/#{group.id}/owners.json", params: {
          group: {
            usernames: [user.username, admin.username].join(",")
          }
        }

        expect(response.status).to eq(404)
      end

      it 'should not allow groups owners to be removed' do
        group.add_owner(user)

        delete "/admin/groups/#{group.id}/owners.json", params: {
          user_id: user.id
        }

        expect(response.status).to eq(404)
      end
    end
  end
end
