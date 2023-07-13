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
end
