# frozen_string_literal: true

RSpec.describe Chat::Api::ThreadReadsController do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  describe "#update" do
    describe "marking the thread messages as read" do
      fab!(:channel) { Fabricate(:chat_channel) }
      fab!(:other_user) { Fabricate(:user) }
      fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
      fab!(:message_1) do
        Fabricate(:chat_message, chat_channel: channel, user: other_user, thread: thread)
      end
      fab!(:message_2) do
        Fabricate(:chat_message, chat_channel: channel, user: other_user, thread: thread)
      end

      context "when the user cannot access the channel" do
        fab!(:channel) { Fabricate(:private_category_channel) }
        fab!(:thread) { Fabricate(:chat_thread, channel: channel) }
        it "raises invalid access" do
          put "/chat/api/channels/#{channel.id}/threads/#{thread.id}/read.json"
          expect(response.status).to eq(403)
        end
      end

      context "when the channel_id and thread_id params do not match" do
        it "raises a not found" do
          put "/chat/api/channels/#{Fabricate(:chat_channel).id}/threads/#{thread.id}/read.json"
          expect(response.status).to eq(404)
        end
      end

      it "marks all mention notifications as read for the thread" do
        notification_1 = create_notification_and_mention_for(current_user, other_user, message_1)
        notification_2 = create_notification_and_mention_for(current_user, other_user, message_2)

        put "/chat/api/channels/#{channel.id}/threads/#{thread.id}/read.json"
        expect(response.status).to eq(200)
        expect(notification_1.reload.read).to eq(true)
        expect(notification_2.reload.read).to eq(true)
      end
    end
  end

  def create_notification_and_mention_for(user, sender, msg)
    Notification
      .create!(
        notification_type: Notification.types[:chat_mention],
        user: user,
        high_priority: true,
        read: false,
        data: {
          message: "chat.mention_notification",
          chat_message_id: msg.id,
          chat_channel_id: msg.chat_channel_id,
          chat_channel_title: msg.chat_channel.title(user),
          chat_channel_slug: msg.chat_channel.slug,
          mentioned_by_username: sender.username,
        }.to_json,
      )
      .tap do |notification|
        Chat::Mention.create!(user: user, chat_message: msg, notification: notification)
      end
  end
end
