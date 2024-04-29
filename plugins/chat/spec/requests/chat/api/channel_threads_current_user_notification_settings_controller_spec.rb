# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelThreadsCurrentUserNotificationsSettingsController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel) { Fabricate(:chat_channel, threading_enabled: true) }
  fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
  fab!(:last_reply) { Fabricate(:chat_message, thread: thread, chat_channel: channel) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
    thread.update!(last_message: last_reply)
  end

  describe "#update" do
    context "when the user cannot access the channel" do
      fab!(:channel) { Fabricate(:private_category_channel) }
      fab!(:thread) { Fabricate(:chat_thread, channel: channel) }

      it "raises invalid access" do
        put "/chat/api/channels/#{channel.id}/threads/#{thread.id}/notifications-settings/me.json",
            params: {
              notification_level: Chat::UserChatThreadMembership.notification_levels[:normal],
            }
        expect(response.status).to eq(403)
      end
    end

    context "when the channel_id and thread_id params do not match" do
      it "raises a not found" do
        put "/chat/api/channels/#{Fabricate(:chat_channel).id}/threads/#{thread.id}/notifications-settings/me.json",
            params: {
              notification_level: Chat::UserChatThreadMembership.notification_levels[:normal],
            }
        expect(response.status).to eq(404)
      end
    end

    context "when the notification_level is invalid" do
      it "raises invalid parameters" do
        put "/chat/api/channels/#{Fabricate(:chat_channel).id}/threads/#{thread.id}/notifications-settings/me.json",
            params: {
              notification_level: 100,
            }
        expect(response.status).to eq(400)
      end
    end

    context "when the user is a member of the thread" do
      before { thread.add(current_user) }

      it "updates the notification_level" do
        expect do
          put "/chat/api/channels/#{channel.id}/threads/#{thread.id}/notifications-settings/me.json",
              params: {
                notification_level: Chat::UserChatThreadMembership.notification_levels[:normal],
              }
        end.not_to change { Chat::UserChatThreadMembership.count }

        expect(response.status).to eq(200)
        expect(thread.membership_for(current_user).notification_level).to eq("normal")
      end
    end

    context "when the user is not a member of the thread" do
      it "creates a membership for the user" do
        expect do
          put "/chat/api/channels/#{channel.id}/threads/#{thread.id}/notifications-settings/me.json",
              params: {
                notification_level: Chat::UserChatThreadMembership.notification_levels[:normal],
              }
        end.to change { Chat::UserChatThreadMembership.count }.by(1)

        expect(response.status).to eq(200)
        expect(response.parsed_body["membership"]).to eq(
          "notification_level" => Chat::UserChatThreadMembership.notification_levels[:normal],
          "thread_id" => thread.id,
          "last_read_message_id" => last_reply.id,
        )
      end
    end
  end
end
