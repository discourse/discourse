# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::DirectMessagesController do
  fab!(:user) { Fabricate(:user) }
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(user)
  end

  def create_dm_channel(user_ids)
    direct_messages_channel = Chat::DirectMessage.create!
    user_ids.each do |user_id|
      direct_messages_channel.direct_message_users.create!(user_id: user_id)
    end
    Chat::DirectMessageChannel.create!(chatable: direct_messages_channel)
  end

  describe "#index" do
    context "when user is not allowed to chat" do
      before { SiteSetting.chat_allowed_groups = nil }

      it "returns a forbidden error" do
        get "/chat/direct_messages.json", params: { usernames: user1.username }
        expect(response.status).to eq(403)
      end
    end

    context "when channel doesn’t exists" do
      it "returns a not found error" do
        get "/chat/direct_messages.json", params: { usernames: user1.username }
        expect(response.status).to eq(404)
      end
    end

    context "when channel exists" do
      let!(:channel) do
        direct_messages_channel = Chat::DirectMessage.create!
        direct_messages_channel.direct_message_users.create!(user_id: user.id)
        direct_messages_channel.direct_message_users.create!(user_id: user1.id)
        Chat::DirectMessageChannel.create!(chatable: direct_messages_channel)
      end

      it "returns the channel" do
        get "/chat/direct_messages.json", params: { usernames: user1.username }
        expect(response.status).to eq(200)
        expect(response.parsed_body["channel"]["id"]).to eq(channel.id)
      end

      context "with more than two users" do
        fab!(:user3) { Fabricate(:user) }
        before { channel.chatable.direct_message_users.create!(user_id: user3.id) }

        it "returns the channel" do
          get "/chat/direct_messages.json",
              params: {
                usernames: [user1.username, user.username, user3.username].join(","),
              }
          expect(response.status).to eq(200)
          expect(response.parsed_body["channel"]["id"]).to eq(channel.id)
        end
      end
    end
  end

  describe "#create" do
    before { Group.refresh_automatic_groups! }

    shared_examples "creating dms" do
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

    describe "dm with one other user" do
      let(:usernames) { user1.username }
      let(:direct_message_user_ids) { [user.id, user1.id] }

      include_examples "creating dms"
    end

    describe "dm with myself" do
      let(:usernames) { [user.username] }
      let(:direct_message_user_ids) { [user.id] }

      include_examples "creating dms"
    end

    describe "dm with two other users" do
      let(:usernames) { [user1, user2, user3].map(&:username) }
      let(:direct_message_user_ids) { [user.id, user1.id, user2.id, user3.id] }

      include_examples "creating dms"
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
      let(:direct_message_user_ids) { [user.id, user1.id, user2.id, user3.id] }

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
          Fabricate(:ignored_user, user: user1, ignored_user: user, expiring_at: 1.day.from_now)
        end

        include_examples "creating dms with communication error"
      end

      describe "user muting the actor" do
        before { Fabricate(:muted_user, user: user1, muted_user: user) }

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
