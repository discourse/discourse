# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelPinsController do
  fab!(:admin)
  fab!(:user)
  fab!(:channel, :chat_channel)
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(admin)
  end

  describe "#index" do
    fab!(:pin) { Fabricate(:chat_pinned_message, chat_message: message, chat_channel: channel) }

    it "returns pinned messages for the channel" do
      Fabricate(:user_chat_channel_membership, chat_channel: channel, user: admin)
      get "/chat/api/channels/#{channel.id}/pins"

      expect(response.status).to eq(200)
      expect(response.parsed_body["pinned_messages"].length).to eq(1)
      expect(response.parsed_body["pinned_messages"][0]["chat_message_id"]).to eq(message.id)
    end

    it "marks pins as read in database but returns old timestamp in response" do
      membership = Fabricate(:user_chat_channel_membership, chat_channel: channel, user: admin)
      expect(membership.last_viewed_pins_at).to be_nil

      freeze_time do
        get "/chat/api/channels/#{channel.id}/pins"

        # Database is updated
        expect(membership.reload.last_viewed_pins_at).to eq_time(Time.zone.now)

        # Response returns old timestamp (nil)
        expect(response.parsed_body["membership"]["last_viewed_pins_at"]).to be_nil
      end
    end

    context "when user cannot access channel" do
      before { sign_in(user) }

      it "returns 403" do
        channel.update!(chatable: Fabricate(:private_category, group: Fabricate(:group)))
        get "/chat/api/channels/#{channel.id}/pins"

        expect(response.status).to eq(403)
      end
    end
  end

  describe "#mark_read" do
    it "marks pins as read for the current user" do
      membership = Fabricate(:user_chat_channel_membership, chat_channel: channel, user: admin)
      expect(membership.last_viewed_pins_at).to be_nil

      freeze_time do
        put "/chat/api/channels/#{channel.id}/pins/read"

        expect(response.status).to eq(200)
        expect(membership.reload.last_viewed_pins_at).to eq_time(Time.zone.now)
      end
    end

    context "when user cannot access channel" do
      before { sign_in(user) }

      it "returns 404" do
        channel.update!(chatable: Fabricate(:private_category, group: Fabricate(:group)))
        put "/chat/api/channels/#{channel.id}/pins/read"

        expect(response.status).to eq(404)
      end
    end
  end

  describe "#create" do
    it "pins a message" do
      post "/chat/api/channels/#{channel.id}/messages/#{message.id}/pin"

      expect(response.status).to eq(200)
      expect(Chat::PinnedMessage.exists?(chat_message_id: message.id)).to eq(true)
    end

    context "when user is not staff" do
      before { sign_in(user) }

      it "returns 403" do
        post "/chat/api/channels/#{channel.id}/messages/#{message.id}/pin"

        expect(response.status).to eq(403)
      end
    end
  end

  describe "#destroy" do
    fab!(:pin) { Fabricate(:chat_pinned_message, chat_message: message, chat_channel: channel) }

    it "unpins a message" do
      delete "/chat/api/channels/#{channel.id}/messages/#{message.id}/pin"

      expect(response.status).to eq(200)
      expect(Chat::PinnedMessage.exists?(chat_message_id: message.id)).to eq(false)
    end

    context "when user is not staff" do
      before { sign_in(user) }

      it "returns 403" do
        delete "/chat/api/channels/#{channel.id}/messages/#{message.id}/pin"

        expect(response.status).to eq(403)
      end
    end
  end
end
