# frozen_string_literal: true

describe Chat::Mention do
  describe "#destroy!" do
    it "bounds notification loading when destroying a message with loaded mention associations" do
      mention = Fabricate(:all_chat_mention)
      other_link = Fabricate(:chat_mention_notification)
      notification_ids =
        Notification
          .insert_all!(
            Array.new(1001) do
              {
                user_id: mention.chat_message.user_id,
                notification_type: Notification.types[:chat_mention],
                data: "{}",
                created_at: Time.current,
                updated_at: Time.current,
              }
            end,
          )
          .rows
          .flatten
      Chat::MentionNotification.insert_all!(
        notification_ids.map do |notification_id|
          { chat_mention_id: mention.id, notification_id: notification_id }
        end,
      )
      orphaned_link = Fabricate(:chat_mention_notification, chat_mention: mention)
      Notification.where(id: orphaned_link.notification_id).delete_all
      message =
        Chat::Message.includes(chat_mentions: :mention_notifications).find(mention.chat_message_id)
      loaded_notifications = []
      subscriber = ->(_name, _start, _finish, _id, payload) do
        loaded_notifications << payload[:record_count] if payload[:class_name] == "Notification"
      end

      ActiveSupport::Notifications.subscribed(subscriber, "instantiation.active_record") do
        message.destroy!
      end

      expect(loaded_notifications).to be_present
      expect(loaded_notifications.max).to be <= 200
      expect(Notification.where(id: notification_ids)).not_to exist
      expect(Chat::MentionNotification.where(chat_mention_id: mention.id)).not_to exist
      expect(described_class.where(id: mention.id)).not_to exist
      expect(Chat::Message.with_deleted.where(id: message.id)).not_to exist
      expect(
        Chat::MentionNotification.where(
          chat_mention_id: other_link.chat_mention_id,
          notification_id: other_link.notification_id,
        ),
      ).to exist
      expect(other_link.notification.reload).to be_present
    end

    it "rolls back message and notification deletion when a notification refuses destruction" do
      mention = Fabricate(:all_chat_mention)
      first_link = Fabricate(:chat_mention_notification, chat_mention: mention)
      last_link = Fabricate(:chat_mention_notification, chat_mention: mention)
      notification_ids = [first_link.notification_id, last_link.notification_id]
      abort_deletion = ->(notification) do
        throw :abort if notification.id == last_link.notification_id
      end
      Notification.set_callback(:destroy, :before, abort_deletion)

      expect { mention.chat_message.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)

      expect(Notification.where(id: notification_ids).count).to eq(2)
      expect(Chat::MentionNotification.where(chat_mention_id: mention.id).count).to eq(2)
      expect(mention.reload).to be_present
      expect(mention.chat_message.reload).to be_present
    ensure
      Notification.skip_callback(:destroy, :before, abort_deletion) if abort_deletion
    end
  end
end
