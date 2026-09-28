# frozen_string_literal: true

describe Chat::Mention do
  describe "#destroy!" do
    it "destroys related notifications and join records while preserving unrelated ones" do
      mention = Fabricate(:all_chat_mention)
      first_link = Fabricate(:chat_mention_notification, chat_mention: mention)
      second_link = Fabricate(:chat_mention_notification, chat_mention: mention)
      other_link = Fabricate(:chat_mention_notification)
      notification_ids = [first_link.notification_id, second_link.notification_id]

      mention.destroy!

      expect(Notification.where(id: notification_ids)).not_to exist
      expect(Chat::MentionNotification.where(chat_mention_id: mention.id)).not_to exist
      expect(
        Chat::MentionNotification.where(
          chat_mention_id: other_link.chat_mention_id,
          notification_id: other_link.notification_id,
        ),
      ).to exist
      expect(other_link.notification.reload).to be_present
    end
  end
end
