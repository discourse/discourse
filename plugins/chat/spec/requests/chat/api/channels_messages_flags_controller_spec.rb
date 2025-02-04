# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsMessagesFlagsController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:message_1) { Fabricate(:chat_message) }

  let(:params) { { flag_type_id: ::ReviewableScore.types[:off_topic] } }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.chat_message_flag_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  describe "#create" do
    it "ratelimits flagging" do
      RateLimiter.enable

      Fabricate
        .times(4, :chat_message)
        .each do |message|
          post "/chat/api/channels/#{message.chat_channel.id}/messages/#{message.id}/flags",
               params: params

          expect(response.status).to eq(200)
        end

      post "/chat/api/channels/#{message_1.chat_channel.id}/messages/#{message_1.id}/flags",
           params: params

      expect(response.status).to eq(429)
    ensure
      RateLimiter.disable
    end

    describe "success" do
      it "works" do
        post "/chat/api/channels/#{message_1.chat_channel.id}/messages/#{message_1.id}/flags",
             params: params

        expect(response.status).to eq(200)
      end
    end

    context "when user can’t flag message" do
      before { UserSilencer.new(current_user).silence }

      it "returns a 403" do
        post "/chat/api/channels/#{message_1.chat_channel.id}/messages/#{message_1.id}/flags",
             params: params

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("invalid_access"))
      end
    end

    context "when channel is not found" do
      it "returns a 404" do
        post "/chat/api/channels/-999/messages/#{message_1.id}/flags", params: params

        expect(response.status).to eq(404)
      end
    end

    context "when message is trashed" do
      before { trash_message!(message_1) }

      it "returns a 403" do
        post "/chat/api/channels/#{message_1.chat_channel.id}/messages/#{message_1.id}/flags",
             params: params

        expect(response.status).to eq(404)
      end
    end

    context "when message is not found" do
      it "returns a 404" do
        post "/chat/api/channels/#{message_1.chat_channel.id}/messages/-999/flags", params: params

        expect(response.status).to eq(404)
      end
    end
  end
end
