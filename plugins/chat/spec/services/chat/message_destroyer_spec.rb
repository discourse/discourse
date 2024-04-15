# frozen_string_literal: true

RSpec.describe Chat::MessageDestroyer do
  describe "#destroy_in_batches" do
    fab!(:message_1) { Fabricate(:chat_message) }
    fab!(:user_1) { Fabricate(:user) }

    it "resets last_read_message_id from memberships" do
      membership =
        Chat::UserChatChannelMembership.create!(
          user: user_1,
          chat_channel: message_1.chat_channel,
          last_read_message: message_1,
          following: true,
          desktop_notification_level: 2,
          mobile_notification_level: 2,
        )

      described_class.new.destroy_in_batches(Chat::Message.where(id: message_1.id))

      expect(membership.reload.last_read_message_id).to be_nil
    end

    it "resets last_read_message_id to the most recent non-deleted message if there is one from memberships" do
      message_2 = Fabricate(:chat_message, chat_channel: message_1.chat_channel)
      message_3 = Fabricate(:chat_message, chat_channel: message_1.chat_channel)
      message_4 = Fabricate(:chat_message, chat_channel: message_1.chat_channel)
      message_1.chat_channel.update(last_message: message_4)
      message_3.trash!
      membership =
        Chat::UserChatChannelMembership.create!(
          user: user_1,
          chat_channel: message_1.chat_channel,
          last_read_message: message_4,
          following: true,
          desktop_notification_level: 2,
          mobile_notification_level: 2,
        )

      described_class.new.destroy_in_batches(Chat::Message.where(id: message_4.id))

      expect(membership.reload.last_read_message_id).to eq(message_2.id)
    end

    it "deletes flags associated to deleted chat messages" do
      guardian = Guardian.new(Discourse.system_user)
      Chat::ReviewQueue.new.flag_message(message_1, guardian, ReviewableScore.types[:off_topic])

      reviewable = Chat::ReviewableMessage.last
      expect(reviewable).to be_present

      described_class.new.destroy_in_batches(Chat::Message.where(id: message_1.id))

      expect { message_1.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      expect { reviewable.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it "doesn't delete other messages" do
      message_2 = Fabricate(:chat_message, chat_channel: message_1.chat_channel)

      described_class.new.destroy_in_batches(Chat::Message.where(id: message_1.id))

      expect { message_1.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      expect(message_2.reload).to be_present
    end

    it "sets the last_message_id for the channel if that message is deleted" do
      message_1.chat_channel.update!(last_message: message_1)
      described_class.new.destroy_in_batches(Chat::Message.where(id: message_1.id))
      expect(message_1.chat_channel.reload.last_message_id).to eq(nil)
    end
  end
end
