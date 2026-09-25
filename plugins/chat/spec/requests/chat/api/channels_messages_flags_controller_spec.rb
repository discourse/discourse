# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsMessagesFlagsController do
  fab!(:current_user, :user)
  fab!(:message_1, :chat_message)

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
      it "flags the message" do
        post "/chat/api/channels/#{message_1.chat_channel.id}/messages/#{message_1.id}/flags",
             params: params

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq("success" => "OK")
      end

      it "returns the domain error when the message has already been flagged" do
        post "/chat/api/channels/#{message_1.chat_channel.id}/messages/#{message_1.id}/flags",
             params: params

        expect(response.status).to eq(200)

        expect {
          post "/chat/api/channels/#{message_1.chat_channel.id}/messages/#{message_1.id}/flags",
               params: params.merge(flag_type_id: ReviewableScore.types[:spam])
        }.not_to change(ReviewableScore, :count)

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq(
          [I18n.t("chat.reviewables.message_already_handled")],
        )
      end
    end

    context "when the notify user companion PM cannot be created" do
      let(:params) do
        {
          flag_type_id: ReviewableScore.types[:notify_user],
          message: "Please review your chat message",
        }
      end

      before { message_1.user.user_option.update!(allow_private_messages: false) }

      it "returns the PostCreator error without creating a PM or reviewable" do
        pm_count = Topic.where(archetype: Archetype.private_message).count
        reviewable_count = Reviewable.count

        post "/chat/api/channels/#{message_1.chat_channel.id}/messages/#{message_1.id}/flags",
             params: params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq(
          [I18n.t("not_accepting_pms", username: message_1.user.username)],
        )
        expect(Topic.where(archetype: Archetype.private_message).count).to eq(pm_count)
        expect(Reviewable.count).to eq(reviewable_count)
      end
    end

    context "when user can't flag message" do
      before { UserSilencer.new(current_user).silence }

      it "returns a 404" do
        post "/chat/api/channels/#{message_1.chat_channel.id}/messages/#{message_1.id}/flags",
             params: params

        expect(response.status).to eq(404)
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

    context "when user cannot access the channel" do
      fab!(:private_channel, :private_category_channel)
      fab!(:private_message) { Fabricate(:chat_message, chat_channel: private_channel) }

      it "returns the same status whether message exists or not" do
        post "/chat/api/channels/#{private_channel.id}/messages/#{private_message.id}/flags",
             params: params
        existing_message_status = response.status

        post "/chat/api/channels/#{private_channel.id}/messages/-999/flags", params: params
        missing_message_status = response.status

        expect(existing_message_status).to eq(missing_message_status)
      end

      it "returns 404 when message exists in inaccessible channel" do
        post "/chat/api/channels/#{private_channel.id}/messages/#{private_message.id}/flags",
             params: params

        expect(response.status).to eq(404)
      end
    end
  end
end
