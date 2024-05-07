# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsMessagesStreamingController do
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#destroy" do
    before { sign_in(current_user) }

    context "when chat is not enabled" do
      it "returns a 404 error" do
        SiteSetting.chat_enabled = false

        delete "/chat/api/channels/-/messages/-/streaming"

        expect(response.status).to eq(404)
      end
    end

    context "when user is not logged" do
      it "returns a 404 error" do
        sign_out

        delete "/chat/api/channels/-/messages/-/streaming"

        expect(response.status).to eq(404)
      end
    end

    context "when the message doesnt exist" do
      it "returns a 404 error" do
        delete "/chat/api/channels/#{channel_1.id}/messages/-999/streaming"

        expect(response.status).to eq(404)
      end
    end

    context "when the user can’t stop" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

      before { channel_1.add(current_user) }

      it "returns a 403 error" do
        delete "/chat/api/channels/#{channel_1.id}/messages/#{message_1.id}/streaming"

        expect(response.status).to eq(403)
      end
    end

    context "when the user is not a member" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }

      it "returns a 404 error" do
        delete "/chat/api/channels/#{channel_1.id}/messages/#{message_1.id}/streaming"

        expect(response.status).to eq(404)
      end
    end

    context "when the user can stop" do
      fab!(:current_user) { Fabricate(:admin) }
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1, user: current_user) }

      before { channel_1.add(current_user) }

      it "returns a 200" do
        delete "/chat/api/channels/#{channel_1.id}/messages/#{message_1.id}/streaming"

        expect(response.status).to eq(200)
      end
    end
  end
end
