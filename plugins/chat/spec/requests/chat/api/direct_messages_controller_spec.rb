# frozen_string_literal: true

RSpec.describe Chat::Api::DirectMessagesController do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  def create_dm_channel(user_ids)
    direct_messages_channel = Chat::DirectMessage.create!(group: user_ids.length > 2)
    user_ids.each do |user_id|
      direct_messages_channel.direct_message_users.create!(user_id: user_id)
    end
    Chat::DirectMessageChannel.create!(chatable: direct_messages_channel)
  end

  describe "#create" do
    describe "dm with one other user" do
      let(:usernames) { user1.username }
      let(:direct_message_user_ids) { [current_user.id, user1.id] }

      it "creates a new dm channel with username(s) provided" do
        expect {
          post "/chat/api/direct-message-channels.json", params: { target_usernames: [usernames] }
        }.to change { Chat::DirectMessage.count }.by(1)
        expect(Chat::DirectMessage.last.direct_message_users.map(&:user_id)).to match_array(
          direct_message_user_ids,
        )
      end

      it "returns existing dm channel if one exists for username(s)" do
        create_dm_channel(direct_message_user_ids)

        expect {
          post "/chat/api/direct-message-channels.json", params: { target_usernames: [usernames] }
        }.not_to change { Chat::DirectMessage.count }
      end
    end

    describe "dm with myself" do
      let(:usernames) { [current_user.username] }
      let(:direct_message_user_ids) { [current_user.id] }

      it "creates a new dm channel with username(s) provided" do
        expect {
          post "/chat/api/direct-message-channels.json", params: { target_usernames: [usernames] }
        }.to change { Chat::DirectMessage.count }.by(1)
        expect(Chat::DirectMessage.last.direct_message_users.map(&:user_id)).to match_array(
          direct_message_user_ids,
        )
      end

      it "returns existing dm channel if one exists for username(s)" do
        create_dm_channel(direct_message_user_ids)

        expect {
          post "/chat/api/direct-message-channels.json", params: { target_usernames: [usernames] }
        }.not_to change { Chat::DirectMessage.count }
      end
    end

    describe "dm with multiple users" do
      let(:usernames) { [user1, user2, user3].map(&:username) }
      let(:direct_message_user_ids) { [current_user.id, user1.id, user2.id, user3.id] }

      it "creates a new dm channel with username(s) provided" do
        expect {
          post "/chat/api/direct-message-channels.json", params: { target_usernames: [usernames] }
        }.to change { Chat::DirectMessage.count }.by(1)
        expect(Chat::DirectMessage.last.direct_message_users.map(&:user_id)).to match_array(
          direct_message_user_ids,
        )
      end

      it "creates a new dm channel" do
        create_dm_channel(direct_message_user_ids)

        expect {
          post "/chat/api/direct-message-channels.json", params: { target_usernames: [usernames] }
        }.to change { Chat::DirectMessage.count }.by(1)
      end

      it "returns existing dm channel when upsert is true" do
        create_dm_channel(direct_message_user_ids)

        expect {
          post "/chat/api/direct-message-channels.json",
               params: {
                 target_usernames: [usernames],
                 upsert: true,
               }
        }.not_to change { Chat::DirectMessage.count }
      end
    end

    it "creates Chat::UserChatChannelMembership records" do
      users = [user2, user3]
      usernames = users.map(&:username)
      expect {
        post "/chat/api/direct-message-channels.json", params: { target_usernames: usernames }
      }.to change { Chat::UserChatChannelMembership.count }.by(3)
    end

    context "when one of the users I am messaging has ignored, muted, or prevented DMs from the acting user creating the channel" do
      let(:usernames) { [user1, user2, user3].map(&:username) }
      let(:direct_message_user_ids) { [current_user.id, user1.id, user2.id, user3.id] }

      shared_examples "creating dms with communication error" do
        it "responds with a friendly error" do
          expect {
            post "/chat/api/direct-message-channels.json", params: { target_usernames: [usernames] }
          }.not_to change { Chat::DirectMessage.count }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to eq(
            [I18n.t("chat.errors.not_accepting_dms", username: user1.username)],
          )
        end
      end

      describe "user ignoring the actor" do
        before do
          Fabricate(
            :ignored_user,
            user: user1,
            ignored_user: current_user,
            expiring_at: 1.day.from_now,
          )
        end

        include_examples "creating dms with communication error"
      end

      describe "user muting the actor" do
        before { Fabricate(:muted_user, user: user1, muted_user: current_user) }

        include_examples "creating dms with communication error"
      end

      describe "user preventing all DMs" do
        before { user1.user_option.update(allow_private_messages: false) }

        include_examples "creating dms with communication error"
      end

      describe "user only allowing DMs from certain users" do
        before { user1.user_option.update(enable_allowed_pm_users: true) }

        include_examples "creating dms with communication error"
      end
    end
  end
end
