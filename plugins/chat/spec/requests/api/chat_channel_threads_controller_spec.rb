# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::Api::ChatChannelThreadsController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:public_channel) { Fabricate(:chat_channel, threading_enabled: true) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.enable_experimental_chat_threaded_discussions = true
    Group.refresh_automatic_groups!
    sign_in(current_user)
  end

  describe "show" do
    context "when thread does not exist" do
      fab!(:thread) do
        Fabricate(
          :chat_thread,
          original_message: Fabricate(:chat_message, chat_channel: public_channel),
        )
      end

      it "returns 404" do
        thread.destroy!
        get "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}"
        expect(response.status).to eq(404)
      end
    end

    context "when thread exists" do
      fab!(:thread) do
        Fabricate(
          :chat_thread,
          original_message: Fabricate(:chat_message, chat_channel: public_channel),
        )
      end

      it "works" do
        get "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}"
        expect(response.status).to eq(200)
        expect(response.parsed_body["thread"]["id"]).to eq(thread.id)
      end

      context "when the channel_id does not match the thread id" do
        fab!(:other_channel) { Fabricate(:chat_channel) }

        it "returns 404" do
          get "/chat/api/channels/#{other_channel.id}/threads/#{thread.id}"
          expect(response.status).to eq(404)
        end
      end

      context "when channel does not have threading enabled" do
        before { thread.channel.update!(threading_enabled: false) }

        it "returns 404" do
          get "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}"
          expect(response.status).to eq(404)
        end
      end

      context "when enable_experimental_chat_threaded_discussions is disabled" do
        before { SiteSetting.enable_experimental_chat_threaded_discussions = false }

        it "returns 404" do
          get "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}"
          expect(response.status).to eq(404)
        end
      end

      context "when user cannot access the channel" do
        before do
          thread.channel.update!(chatable: Fabricate(:private_category, group: Fabricate(:group)))
        end

        it "returns 403" do
          get "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}"
          expect(response.status).to eq(403)
        end
      end

      context "when user cannot chat" do
        before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_4] }

        it "returns 403" do
          get "/chat/api/channels/#{thread.channel_id}/threads/#{thread.id}"
          expect(response.status).to eq(403)
        end
      end
    end
  end
end
