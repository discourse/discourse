# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelMessageBroadcastController do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:channel) do
    Fabricate(:category_channel, threading_enabled: true, broadcast_replies_enabled: true)
  end
  fab!(:thread) { Fabricate(:chat_thread, channel:) }
  fab!(:reply) { Fabricate(:chat_message, chat_channel: channel, user:, thread:) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel.add(user)
    sign_in(user)
  end

  describe "#create" do
    it "broadcasts a thread reply into the channel" do
      post "/chat/api/channels/#{channel.id}/messages/#{reply.id}/broadcast"

      expect(response.status).to eq(200)
      expect(reply.reload.broadcasted).to be(true)
    end

    it "returns a 422 when the message is the thread original message" do
      thread.original_message.update!(user:)

      post "/chat/api/channels/#{channel.id}/messages/#{thread.original_message_id}/broadcast"

      expect(response.status).to eq(422)
    end

    it "returns a 422 when the channel option is disabled" do
      channel.update!(broadcast_replies_enabled: false)

      post "/chat/api/channels/#{channel.id}/messages/#{reply.id}/broadcast"

      expect(response.status).to eq(422)
      expect(reply.reload.broadcasted).to be(false)
    end

    it "returns a 403 for a user who is not the author" do
      channel.add(other_user)
      sign_in(other_user)

      post "/chat/api/channels/#{channel.id}/messages/#{reply.id}/broadcast"
      expect(response.status).to eq(403)
    end
  end

  describe "#destroy" do
    it "removes a broadcasted reply from the channel" do
      reply.update!(broadcasted: true)

      delete "/chat/api/channels/#{channel.id}/messages/#{reply.id}/broadcast"

      expect(response.status).to eq(200)
      expect(reply.reload.broadcasted).to be(false)
    end

    it "removes a broadcast even when the channel option is now disabled" do
      reply.update!(broadcasted: true)
      channel.update!(broadcast_replies_enabled: false)

      delete "/chat/api/channels/#{channel.id}/messages/#{reply.id}/broadcast"

      expect(response.status).to eq(200)
      expect(reply.reload.broadcasted).to be(false)
    end
  end
end
