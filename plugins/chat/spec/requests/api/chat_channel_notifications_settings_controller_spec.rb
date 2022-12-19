# frozen_string_literal: true

RSpec.describe Chat::Api::ChatChannelNotificationsSettingsController do
  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  fab!(:chat_channel) { Fabricate(:category_channel) }
  fab!(:user) { Fabricate(:user) }

  describe "#update" do
    include_examples "channel access example", :put, "/notifications_settings.json"

    it 'calls guardian ensure_can_join_chat_channel!' do
      sign_in(user)
      Guardian.any_instance.expects(:ensure_can_join_chat_channel!).once
      put "/chat/api/chat_channels/#{chat_channel.id}/notifications_settings.json",
        params: {
          muted: true,
          desktop_notification_level: "always",
          mobile_notification_level: "never",
        }
    end

    context "when category channel has invalid params" do
      fab!(:membership) do
        Fabricate(:user_chat_channel_membership, user: user, chat_channel: chat_channel)
      end

      before { sign_in(user) }

      it "doesn’t use invalid params" do
        UserChatChannelMembership.any_instance.expects(:update!).with({ "muted" => "true" }).once

        put "/chat/api/chat_channels/#{chat_channel.id}/notifications_settings.json",
            params: {
              muted: true,
              foo: 1,
            }

        expect(response.status).to eq(200)
      end
    end

    context "when category channel has valid params" do
      fab!(:membership) do
        Fabricate(
          :user_chat_channel_membership,
          muted: false,
          user: user,
          chat_channel: chat_channel,
        )
      end

      before { sign_in(user) }

      it "updates the notifications settings" do
        put "/chat/api/chat_channels/#{chat_channel.id}/notifications_settings.json",
            params: {
              muted: true,
              desktop_notification_level: "always",
              mobile_notification_level: "never",
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body).to match_response_schema("user_chat_channel_membership")

        membership.reload

        expect(membership.muted).to eq(true)
        expect(membership.desktop_notification_level).to eq("always")
        expect(membership.mobile_notification_level).to eq("never")
      end
    end

    context "when membership doesn’t exist" do
      fab!(:chat_channel) { Fabricate(:category_channel) }
      fab!(:user) { Fabricate(:user) }

      before { sign_in(user) }

      it "raises a 404" do
        put "/chat/api/chat_channels/#{chat_channel.id}/notifications_settings.json"

        expect(response.status).to eq(404)
      end
    end

    context "when direct message channel has invalid params" do
      fab!(:user) { Fabricate(:user) }
      fab!(:chat_channel) { Fabricate(:direct_message_channel, users: [user, Fabricate(:user)]) }
      fab!(:membership) do
        Fabricate(:user_chat_channel_membership, user: user, chat_channel: chat_channel)
      end

      before { sign_in(user) }

      it "doesn’t use invalid params" do
        UserChatChannelMembership.any_instance.expects(:update!).with({ "muted" => "true" }).once

        put "/chat/api/chat_channels/#{chat_channel.id}/notifications_settings.json",
            params: {
              muted: true,
              foo: 1,
            }

        expect(response.status).to eq(200)
      end
    end

    context "when direct message channel has valid params" do
      fab!(:user) { Fabricate(:user) }
      fab!(:chat_channel) { Fabricate(:direct_message_channel, users: [user, Fabricate(:user)]) }
      fab!(:membership) do
        Fabricate(
          :user_chat_channel_membership,
          muted: false,
          user: user,
          chat_channel: chat_channel,
        )
      end

      before { sign_in(user) }

      it "updates the notifications settings" do
        put "/chat/api/chat_channels/#{chat_channel.id}/notifications_settings.json",
            params: {
              muted: true,
              desktop_notification_level: "always",
              mobile_notification_level: "never",
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body).to match_response_schema("user_chat_channel_membership")

        membership.reload

        expect(membership.muted).to eq(true)
        expect(membership.desktop_notification_level).to eq("always")
        expect(membership.mobile_notification_level).to eq("never")
      end
    end
  end
end
