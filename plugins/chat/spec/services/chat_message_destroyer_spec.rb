# frozen_string_literal: true

RSpec.describe ChatMessageDestroyer do
  describe "#destroy_in_batches" do
    fab!(:message_1) { Fabricate(:chat_message) }
    fab!(:user_1) { Fabricate(:user) }

    it "resets last_read_message_id from memberships" do
      membership =
        UserChatChannelMembership.create!(
          user: user_1,
          chat_channel: message_1.chat_channel,
          last_read_message: message_1,
          following: true,
          desktop_notification_level: 2,
          mobile_notification_level: 2,
        )

      described_class.new.destroy_in_batches(ChatMessage.where(id: message_1.id))

      expect(membership.reload.last_read_message_id).to be_nil
    end

    it "deletes flags associated to deleted chat messages" do
      guardian = Guardian.new(Discourse.system_user)
      Chat::ChatReviewQueue.new.flag_message(message_1, guardian, ReviewableScore.types[:off_topic])

      reviewable = ReviewableChatMessage.last
      expect(reviewable).to be_present

      described_class.new.destroy_in_batches(ChatMessage.where(id: message_1.id))

      expect { message_1.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      expect { reviewable.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it "doesn't delete other messages" do
      message_2 = Fabricate(:chat_message, chat_channel: message_1.chat_channel)

      described_class.new.destroy_in_batches(ChatMessage.where(id: message_1.id))

      expect { message_1.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      expect(message_2.reload).to be_present
    end
  end

  describe "#trash_message" do
    fab!(:message_1) { Fabricate(:chat_message) }
    fab!(:actor) { Discourse.system_user }

    it "trashes the message" do
      described_class.new.trash_message(message_1, actor)

      expect(ChatMessage.find_by(id: message_1.id)).to be_blank
      expect(ChatMessage.with_deleted.find_by(id: message_1.id)).to be_present
    end

    context "when the message has associated notifications" do
      context "when notification has the chat_mention type" do
        it "deletes associated notification and chat mention relations" do
          notification =
            Fabricate(:notification, notification_type: Notification.types[:chat_mention])
          chat_mention =
            Fabricate(:chat_mention, chat_message: message_1, notification: notification)

          described_class.new.trash_message(message_1, actor)

          expect { notification.reload }.to raise_error(ActiveRecord::RecordNotFound)
          expect { chat_mention.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    it "publishes a MB message to update clients" do
      delete_message =
        MessageBus
          .track_publish("/chat/#{message_1.chat_channel_id}") do
            described_class.new.trash_message(message_1, actor)
          end
          .first

      expect(delete_message).to be_present
      message_data = delete_message.data

      expect(message_data[:type]).to eq("delete")
      expect(message_data[:deleted_id]).to eq(message_1.id)
      expect(message_data[:deleted_at]).to be_present
    end
  end
end
