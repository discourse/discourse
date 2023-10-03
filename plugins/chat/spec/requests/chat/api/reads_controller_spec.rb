# frozen_string_literal: true

RSpec.describe Chat::Api::ReadsController do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  describe "#read" do
    describe "marking a single message read" do
      fab!(:chat_channel) { Fabricate(:chat_channel) }
      fab!(:other_user) { Fabricate(:user) }
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel, user: other_user) }
      fab!(:message_2) { Fabricate(:chat_message, chat_channel: chat_channel, user: other_user) }

      it "returns a 404 when the user is not a channel member" do
        put "/chat/api/channels/#{chat_channel.id}/read/#{message_1.id}.json"
        expect(response.status).to eq(404)
      end

      it "returns a 404 when the user is not following the channel" do
        Fabricate(
          :user_chat_channel_membership,
          chat_channel: chat_channel,
          user: current_user,
          following: false,
        )

        put "/chat/api/channels/#{chat_channel.id}/read/#{message_1.id}.json"
        expect(response.status).to eq(404)
      end

      describe "when the user is a channel member" do
        fab!(:membership) do
          Fabricate(:user_chat_channel_membership, chat_channel: chat_channel, user: current_user)
        end

        context "when message_id param doesn't link to a message of the channel" do
          it "raises a not found" do
            put "/chat/api/channels/#{chat_channel.id}/read/-999.json"
            expect(response.status).to eq(404)
          end
        end

        context "when message_id param is inferior to existing last read" do
          before { membership.update!(last_read_message_id: message_2.id) }

          it "raises an invalid request" do
            put "/chat/api/channels/#{chat_channel.id}/read/#{message_1.id}.json"
            expect(response.status).to eq(400)
            expect(response.parsed_body["errors"][0]).to match(/message_id/)
          end
        end

        context "when message_id refers to deleted message" do
          before { message_1.trash!(Discourse.system_user) }

          it "works" do
            put "/chat/api/channels/#{chat_channel.id}/read/#{message_1.id}"
            expect(response.status).to eq(200)
          end
        end

        it "updates timing records" do
          expect {
            put "/chat/api/channels/#{chat_channel.id}/read/#{message_1.id}.json"
          }.not_to change { Chat::UserChatChannelMembership.count }

          membership.reload
          expect(membership.chat_channel_id).to eq(chat_channel.id)
          expect(membership.last_read_message_id).to eq(message_1.id)
          expect(membership.user_id).to eq(current_user.id)
        end

        it "marks all mention notifications as read for the channel" do
          notification = create_notification_and_mention_for(current_user, other_user, message_1)

          put "/chat/api/channels/#{chat_channel.id}/read/#{message_2.id}.json"
          expect(response.status).to eq(200)
          expect(notification.reload.read).to eq(true)
        end

        it "doesn't mark notifications of messages that weren't read yet" do
          message_3 = Fabricate(:chat_message, chat_channel: chat_channel, user: other_user)
          notification = create_notification_and_mention_for(current_user, other_user, message_3)

          put "/chat/api/channels/#{chat_channel.id}/read/#{message_2.id}.json"
          expect(response.status).to eq(200)
          expect(notification.reload.read).to eq(false)
        end
      end
    end

    describe "marking all messages read" do
      fab!(:chat_channel_1) { Fabricate(:chat_channel) }
      fab!(:chat_channel_2) { Fabricate(:chat_channel) }
      fab!(:chat_channel_3) { Fabricate(:chat_channel) }

      fab!(:other_user) { Fabricate(:user) }

      fab!(:message_1) { Fabricate(:chat_message, chat_channel: chat_channel_1, user: other_user) }
      fab!(:message_2) { Fabricate(:chat_message, chat_channel: chat_channel_1, user: other_user) }
      fab!(:message_3) { Fabricate(:chat_message, chat_channel: chat_channel_2, user: other_user) }
      fab!(:message_4) { Fabricate(:chat_message, chat_channel: chat_channel_2, user: other_user) }
      fab!(:message_5) { Fabricate(:chat_message, chat_channel: chat_channel_3, user: other_user) }
      fab!(:message_6) { Fabricate(:chat_message, chat_channel: chat_channel_3, user: other_user) }

      fab!(:membership_1) do
        Fabricate(
          :user_chat_channel_membership,
          chat_channel: chat_channel_1,
          user: current_user,
          following: true,
        )
      end
      fab!(:membership_2) do
        Fabricate(
          :user_chat_channel_membership,
          chat_channel: chat_channel_2,
          user: current_user,
          following: true,
        )
      end
      fab!(:membership_3) do
        Fabricate(
          :user_chat_channel_membership,
          chat_channel: chat_channel_3,
          user: current_user,
          following: true,
        )
      end

      before do
        chat_channel_1.update!(last_message: message_2)
        chat_channel_2.update!(last_message: message_4)
        chat_channel_3.update!(last_message: message_6)
      end

      it "marks all messages as read across the user's channel memberships with the correct last_read_message_id" do
        put "/chat/api/channels/read.json"

        expect(membership_1.reload.last_read_message_id).to eq(message_2.id)
        expect(membership_2.reload.last_read_message_id).to eq(message_4.id)
        expect(membership_3.reload.last_read_message_id).to eq(message_6.id)
      end

      it "doesn't mark messages for channels the user is not following as read" do
        membership_1.update!(following: false)

        put "/chat/api/channels/read.json"

        expect(membership_1.reload.last_read_message_id).to eq(nil)
        expect(membership_2.reload.last_read_message_id).to eq(message_4.id)
        expect(membership_3.reload.last_read_message_id).to eq(message_6.id)
      end

      it "returns the updated memberships, channels, and last message id" do
        put "/chat/api/channels/read.json"
        expect(response.parsed_body["updated_memberships"]).to match_array(
          [
            {
              "channel_id" => chat_channel_1.id,
              "last_read_message_id" => message_2.id,
              "membership_id" => membership_1.id,
            },
            {
              "channel_id" => chat_channel_2.id,
              "last_read_message_id" => message_4.id,
              "membership_id" => membership_2.id,
            },
            {
              "channel_id" => chat_channel_3.id,
              "last_read_message_id" => message_6.id,
              "membership_id" => membership_3.id,
            },
          ],
        )
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
