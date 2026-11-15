# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsCurrentUserNotificationsSettingsController do
  fab!(:current_user, :user)

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
      fab!(:channel_1, :category_channel)

      before do
        channel_1.add(current_user)
        sign_in(current_user)
      end

      it "doesn’t use invalid params" do
        Chat::UserChatChannelMembership
          .any_instance
          .expects(:update!)
          .with({ "muted" => "true", "muted_until" => nil })
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
      fab!(:channel_1, :category_channel)

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

    context "when muting for a duration" do
      fab!(:channel_1, :category_channel)

      before do
        channel_1.add(current_user)
        sign_in(current_user)
      end

      it "mutes the channel until the given time" do
        freeze_time Time.zone.parse("2026-01-01 12:00")

        put "/chat/api/channels/#{channel_1.id}/notifications-settings/me",
            params: {
              notifications_settings: {
                muted: true,
                muted_until: 15.minutes.from_now.iso8601,
              },
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["membership"]).to match_response_schema(
          "user_chat_channel_membership",
        )
        expect(Time.zone.parse(response.parsed_body["membership"]["muted_until"])).to eq_time(
          15.minutes.from_now,
        )

        membership = channel_1.membership_for(current_user)

        expect(membership.muted).to eq(true)
        expect(membership.muted_until).to eq_time(15.minutes.from_now)
      end

      it "clears the end time when muting without one" do
        channel_1.membership_for(current_user).update!(muted: true, muted_until: 1.hour.from_now)

        put "/chat/api/channels/#{channel_1.id}/notifications-settings/me",
            params: {
              notifications_settings: {
                muted: true,
              },
            }

        expect(response.status).to eq(200)

        membership = channel_1.membership_for(current_user)

        expect(membership.muted).to eq(true)
        expect(membership.muted_until).to be_nil
      end

      it "rejects an invalid end time" do
        put "/chat/api/channels/#{channel_1.id}/notifications-settings/me",
            params: {
              notifications_settings: {
                muted: true,
                muted_until: "not a time",
              },
            }

        expect(response.status).to eq(400)
        expect(channel_1.membership_for(current_user).muted).to eq(false)
      end

      it "rejects an end time in the past" do
        put "/chat/api/channels/#{channel_1.id}/notifications-settings/me",
            params: {
              notifications_settings: {
                muted: true,
                muted_until: 1.minute.ago.iso8601,
              },
            }

        expect(response.status).to eq(422)
        expect(channel_1.membership_for(current_user).muted).to eq(false)
      end
    end

    context "when membership doesn’t exist" do
      fab!(:channel_1, :category_channel)

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
          .with({ "muted" => "true", "muted_until" => nil })
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
