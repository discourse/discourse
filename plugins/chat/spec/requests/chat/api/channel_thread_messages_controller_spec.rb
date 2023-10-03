# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::Api::ChannelThreadMessagesController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:thread) do
    Fabricate(:chat_thread, channel: Fabricate(:chat_channel, threading_enabled: true))
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    thread.channel.add(current_user)
    sign_in(current_user)
  end

  describe "index" do
    describe "success" do
      fab!(:message_1) { Fabricate(:chat_message, thread: thread, chat_channel: thread.channel) }
      fab!(:message_2) { Fabricate(:chat_message, chat_channel: thread.channel) }

      it "works" do
        get "/chat/api/channels/#{thread.channel.id}/threads/#{thread.id}/messages"

        expect(response.status).to eq(200)
        expect(response.parsed_body["messages"].map { |m| m["id"] }).to contain_exactly(
          thread.original_message.id,
          message_1.id,
        )
      end
    end

    context "when thread doesn’t exist" do
      it "returns a 404" do
        get "/chat/api/channels/#{thread.channel.id}/threads/-999/messages"

        expect(response.status).to eq(404)
      end
    end

    context "when target message doesn’t exist" do
      it "returns a 404" do
        get "/chat/api/channels/#{thread.channel.id}/threads/#{thread.id}/messages?target_message_id=-999"

        expect(response.status).to eq(404)
      end
    end

    context "when user can’t see channel" do
      fab!(:thread) do
        Fabricate(
          :chat_thread,
          channel: Fabricate(:private_category_channel, threading_enabled: true),
        )
      end

      it "returns a 403" do
        get "/chat/api/channels/#{thread.channel.id}/threads/#{thread.id}/messages"

        expect(response.status).to eq(403)
      end
    end

    context "when channel disabled threading" do
      fab!(:thread) do
        Fabricate(:chat_thread, channel: Fabricate(:chat_channel, threading_enabled: false))
      end

      it "returns a 404" do
        get "/chat/api/channels/#{thread.channel.id}/threads/#{thread.id}/messages"

        expect(response.status).to eq(404)
      end
    end
  end
end
