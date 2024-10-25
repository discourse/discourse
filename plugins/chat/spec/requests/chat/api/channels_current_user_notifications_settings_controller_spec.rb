# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsCurrentUserNotificationsSettingsController do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#update" do
    include_examples "channel access example",
                     :put,
                     "/notifications-settings/me",
                     { notifications_settings: { muted: true } }

    context "when category channel has invalid params" do
      fab!(:channel_1) { Fabricate(:category_channel) }

      before do
        channel_1.add(current_user)
        sign_in(current_user)
      end

      it "doesn’t use invalid params" do
        Chat::UserChatChannelMembership
          .any_instance
          .expects(:update!)
          .with({ "muted" => "true" })
          .once

        put "/chat/api/channels/#{channel_1.id}/notifications-settings/me",
            params: {
              notifications_settings: {
                muted: true,
                foo: 1,
              },
            }

        expect(response.status).to eq(200)
      end
    end

    context "when category channel has valid params" do
      fab!(:channel_1) { Fabricate(:category_channel) }

      before do
        channel_1.add(current_user)
        sign_in(current_user)
      end

      it "updates the notifications settings" do
        put "/chat/api/channels/#{channel_1.id}/notifications-settings/me",
            params: {
              notifications_settings: {
                muted: true,
                notification_level: "always",
              },
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["membership"]).to match_response_schema(
          "user_chat_channel_membership",
        )

        membership = channel_1.membership_for(current_user)

        expect(membership.muted).to eq(true)
        expect(membership.notification_level).to eq("always")
      end
    end

    context "when membership doesn’t exist" do
      fab!(:channel_1) { Fabricate(:category_channel) }

      before { sign_in(current_user) }

      it "raises a 404" do
        put "/chat/api/channels/#{channel_1.id}/notifications-settings/me",
            params: {
              notifications_settings: {
                muted: true,
              },
            }

        expect(response.status).to eq(404)
      end
    end

    context "when direct message channel has invalid params" do
      fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

      before { sign_in(current_user) }

      it "doesn’t use invalid params" do
        Chat::UserChatChannelMembership
          .any_instance
          .expects(:update!)
          .with({ "muted" => "true" })
          .once

        put "/chat/api/channels/#{dm_channel_1.id}/notifications-settings/me",
            params: {
              notifications_settings: {
                muted: true,
                foo: 1,
              },
            }

        expect(response.status).to eq(200)
      end
    end

    context "when direct message channel has valid params" do
      fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

      before { sign_in(current_user) }

      it "updates the notifications settings" do
        put "/chat/api/channels/#{dm_channel_1.id}/notifications-settings/me",
            params: {
              notifications_settings: {
                muted: true,
                notification_level: "always",
              },
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["membership"]).to match_response_schema(
          "user_chat_channel_membership",
        )

        membership = dm_channel_1.membership_for(current_user)

        expect(membership.muted).to eq(true)
        expect(membership.notification_level).to eq("always")
      end
    end
  end
end
