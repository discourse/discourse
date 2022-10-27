# frozen_string_literal: true

module Jobs
  class DeleteOldChatMessages < ::Jobs::Scheduled
    daily at: 0.hours

    def execute(args = {})
      delete_public_channel_messages
      delete_dm_channel_messages
    end

    def delete_public_channel_messages
      return unless valid_day_value?(:chat_channel_retention_days)

      ChatMessage
        .in_public_channel
        .with_deleted
        .created_before(SiteSetting.chat_channel_retention_days.days.ago)
        .in_batches(of: 200)
        .each do |relation|
          destroyed_ids = relation.destroy_all.pluck(:id)
          reset_last_read_message_id(destroyed_ids)
          delete_flags(destroyed_ids)
        end
    end

    def delete_dm_channel_messages
      return unless valid_day_value?(:chat_dm_retention_days)

      ChatMessage
        .in_dm_channel
        .with_deleted
        .created_before(SiteSetting.chat_dm_retention_days.days.ago)
        .in_batches(of: 200)
        .each do |relation|
          destroyed_ids = relation.destroy_all.pluck(:id)
          reset_last_read_message_id(destroyed_ids)
        end
    end

    def valid_day_value?(setting_name)
      (SiteSetting.public_send(setting_name) || 0).positive?
    end

    def reset_last_read_message_id(ids)
      UserChatChannelMembership.where(last_read_message_id: ids).update_all(
        last_read_message_id: nil,
      )
    end

    def delete_flags(message_ids)
      ReviewableChatMessage.where(target_id: message_ids).destroy_all
    end
  end
end
