# frozen_string_literal: true

RSpec.describe Chat::Api::ChatTrackingController do
  describe "#update_user_last_read" do
    before { sign_in(user) }

    fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel, user: other_user) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: chat_channel, user: other_user) }

    it "returns a 404 when the user is not a channel member" do
      put "/chat/#{chat_channel.id}/read/#{message_1.id}.json"

      expect(response.status).to eq(404)
    end

    it "returns a 404 when the user is not following the channel" do
      Fabricate(
        :user_chat_channel_membership,
        chat_channel: chat_channel,
        user: user,
        following: false,
      )

      put "/chat/#{chat_channel.id}/read/#{message_1.id}.json"

      expect(response.status).to eq(404)
    end

    describe "when the user is a channel member" do
      fab!(:membership) do
        Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: user)
      end

      context "when message_id param doesn't link to a message of the channel" do
        it "raises a not found" do
          put "/chat/#{chat_channel.id}/read/-999.json"

          expect(response.status).to eq(404)
        end
      end

      context "when message_id param is inferior to existing last read" do
        before { membership.update!(last_read_message_id: message_2.id) }

        it "raises an invalid request" do
          put "/chat/#{chat_channel.id}/read/#{message_1.id}.json"

          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"][0]).to match(/message_id/)
        end
      end

      context "when message_id refers to deleted message" do
        before { message_1.trash!(Discourse.system_user) }

        it "works" do
          put "/chat/#{chat_channel.id}/read/#{message_1.id}.json"

          expect(response.status).to eq(200)
        end
      end

      it "updates timing records" do
        expect { put "/chat/#{chat_channel.id}/read/#{message_1.id}.json" }.not_to change {
          UserChatChannelMembership.count
        }

        membership.reload
        expect(membership.chat_channel_id).to eq(chat_channel.id)
        expect(membership.last_read_message_id).to eq(message_1.id)
        expect(membership.user_id).to eq(user.id)
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
            ChatMention.create!(user: user, chat_message: msg, notification: notification)
          end
      end

      it "marks all mention notifications as read for the channel" do
        notification = create_notification_and_mention_for(user, other_user, message_1)

        put "/chat/#{chat_channel.id}/read/#{message_2.id}.json"
        expect(response.status).to eq(200)
        expect(notification.reload.read).to eq(true)
      end

      it "doesn't mark notifications of messages that weren't read yet" do
        message_3 = Fabricate(:chat_message, chat_channel: chat_channel, user: other_user)
        notification = create_notification_and_mention_for(user, other_user, message_3)

        put "/chat/#{chat_channel.id}/read/#{message_2.id}.json"

        expect(response.status).to eq(200)
        expect(notification.reload.read).to eq(false)
      end
    end
  end
end
