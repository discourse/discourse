# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::Api::ChannelMessagesController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel) { Fabricate(:chat_channel) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    channel.add(current_user)
    sign_in(current_user)
  end

  describe "index" do
    describe "success" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }
      fab!(:message_2) { Fabricate(:chat_message) }

      it "works" do
        get "/chat/api/channels/#{channel.id}/messages"

        expect(response.status).to eq(200)
        expect(response.parsed_body["messages"].map { |m| m["id"] }).to contain_exactly(
          message_1.id,
        )
      end
    end

    context "when readonly mode" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }

      before { Discourse.enable_readonly_mode }
      after { Discourse.disable_readonly_mode }

      it "works" do
        get "/chat/api/channels/#{channel.id}/messages"

        expect(response.status).to eq(200)
      end
    end

    context "when channnel doesn’t exist" do
      it "returns a 404" do
        get "/chat/api/channels/-999/messages"

        expect(response.status).to eq(404)
      end
    end

    context "when target message doesn’t exist" do
      it "returns a 404" do
        get "/chat/api/channels/#{channel.id}/messages?target_message_id=-999"

        expect(response.status).to eq(404)
      end
    end

    context "when user can’t see channel" do
      fab!(:channel) { Fabricate(:private_category_channel) }

      it "returns a 403" do
        get "/chat/api/channels/#{channel.id}/messages"

        expect(response.status).to eq(403)
      end
    end
  end
end
