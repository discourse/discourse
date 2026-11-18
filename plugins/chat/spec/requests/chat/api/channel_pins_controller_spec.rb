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
    it "returns pinned messages for the channel" do
      Fabricate(:chat_pinned_message, chat_message: message, chat_channel: channel)
      Fabricate(:user_chat_channel_membership, chat_channel: channel, user: admin)
      get "/chat/api/channels/#{channel.id}/pins"

      expect(response.status).to eq(200)
      expect(response.parsed_body["pinned_messages"].length).to eq(1)
      expect(response.parsed_body["pinned_messages"][0]["chat_message_id"]).to eq(message.id)
    end

    it "returns pinned messages to users outside the pinning groups" do
      sign_in(user)
      Fabricate(:chat_pinned_message, chat_message: message, chat_channel: channel)

      get "/chat/api/channels/#{channel.id}/pins"

      expect(response.status).to eq(200)
      expect(response.parsed_body["pinned_messages"].map { |pin| pin["chat_message_id"] }).to eq(
        [message.id],
      )
      expect(response.parsed_body["pinned_messages"][0]["message"]["pinned"]).to eq(true)
    end

    it "keeps links in the pin excerpt, unlike the message's own excerpt" do
      linked = Fabricate(:chat_message, chat_channel: channel, message: "see [the docs](/faq)")
      Fabricate(:chat_pinned_message, chat_message: linked, chat_channel: channel)

      get "/chat/api/channels/#{channel.id}/pins"

      pin = response.parsed_body["pinned_messages"][0]
      expect(pin["excerpt"]).to include("<a href=\"/faq\"")
      expect(pin["message"]["excerpt"]).not_to include("<a")
    end

    it "keeps a link for a pin whose message is only a URL" do
      url_only =
        Fabricate(:chat_message, chat_channel: channel, message: "https://example.com/docs")
      Fabricate(:chat_pinned_message, chat_message: url_only, chat_channel: channel)

      get "/chat/api/channels/#{channel.id}/pins"

      pin = response.parsed_body["pinned_messages"][0]
      expect(pin["excerpt"]).to include("<a href=\"https://example.com/docs\"")
      expect(pin["excerpt"]).to include("rel=\"noopener nofollow ugc\"")
    end

    it "returns an empty list when there are no pinned messages" do
      get "/chat/api/channels/#{channel.id}/pins"

      expect(response.status).to eq(200)
      expect(response.parsed_body["pinned_messages"].length).to eq(0)
    end

    it "does not mark pins as read" do
      membership = Fabricate(:user_chat_channel_membership, chat_channel: channel, user: admin)

      get "/chat/api/channels/#{channel.id}/pins"

      expect(membership.reload.last_viewed_pins_at).to be_nil
    end

    context "when user cannot access channel" do
      before { sign_in(user) }

      it "returns 403" do
        channel.update!(chatable: Fabricate(:private_category, group: Fabricate(:group)))
        get "/chat/api/channels/#{channel.id}/pins"

        expect(response.status).to eq(403)
      end
    end

    context "when user can only see a readonly category channel" do
      fab!(:readonly_group) { Fabricate(:group, users: [user]) }
      fab!(:channel) do
        category =
          Fabricate(
            :private_category,
            group: readonly_group,
            permission_type: CategoryGroup.permission_types[:readonly],
          )
        Fabricate(:category_channel, chatable: category)
      end
      fab!(:message) do
        Fabricate(
          :chat_message,
          chat_channel: channel,
          message: "Confidential restricted pinned message",
        )
      end

      before { sign_in(user) }

      it "does not expose pinned messages" do
        Fabricate(:chat_pinned_message, chat_channel: channel, chat_message: message)

        get "/chat/api/channels/#{channel.id}/pins"

        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")
        expect(response.body).not_to include(message.message)
      end
    end

    context "when a pinned reply's thread original message was trashed" do
      fab!(:thread_channel) { Fabricate(:category_channel, threading_enabled: true) }
      fab!(:original_message) do
        Fabricate(:chat_message, chat_channel: thread_channel, message: "thread original secret")
      end
      fab!(:thread) do
        Fabricate(:chat_thread, channel: thread_channel, original_message: original_message)
      end
      fab!(:reply) do
        Fabricate(
          :chat_message,
          chat_channel: thread_channel,
          thread: thread,
          message: "thread reply secret",
        )
      end

      before do
        Fabricate(:chat_pinned_message, chat_message: reply, chat_channel: thread_channel)
        original_message.trash!(admin)
        sign_in(user)
      end

      it "does not expose the pinned reply to a regular member" do
        get "/chat/api/channels/#{thread_channel.id}/pins"

        expect(response.status).to eq(200)
        expect(response.parsed_body["pinned_messages"]).to be_empty
        expect(response.body).not_to include("thread reply secret")
      end

      it "still exposes the pinned reply to a chat moderator" do
        sign_in(admin)

        get "/chat/api/channels/#{thread_channel.id}/pins"

        expect(response.status).to eq(200)
        expect(response.parsed_body["pinned_messages"].map { |pin| pin["chat_message_id"] }).to eq(
          [reply.id],
        )
        expect(response.body).to include("thread reply secret")
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

    it "allows members of the configured pinning groups to pin messages" do
      sign_in(user)
      group = Fabricate(:group, users: [user])
      SiteSetting.chat_pinning_messages_allowed_groups = group.id.to_s

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

    context "when the message is a reply whose thread original message was trashed" do
      fab!(:thread_channel) { Fabricate(:category_channel, threading_enabled: true) }
      fab!(:original_message) do
        Fabricate(:chat_message, chat_channel: thread_channel, message: "thread original secret")
      end
      fab!(:thread) do
        Fabricate(:chat_thread, channel: thread_channel, original_message: original_message)
      end
      fab!(:reply) { Fabricate(:chat_message, chat_channel: thread_channel, thread: thread) }

      before do
        original_message.trash!(admin)
        group = Fabricate(:group, users: [user])
        SiteSetting.chat_pinning_messages_allowed_groups = group.id.to_s
        sign_in(user)
      end

      it "does not let a pinning group member pin the hidden reply" do
        post "/chat/api/channels/#{thread_channel.id}/messages/#{reply.id}/pin"

        expect(response.status).to eq(403)
        expect(Chat::PinnedMessage.exists?(chat_message_id: reply.id)).to eq(false)
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

    it "allows members of the configured pinning groups to unpin messages" do
      sign_in(user)
      group = Fabricate(:group, users: [user])
      SiteSetting.chat_pinning_messages_allowed_groups = group.id.to_s

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
