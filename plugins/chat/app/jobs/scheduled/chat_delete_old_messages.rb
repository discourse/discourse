# frozen_string_literal: true

module Jobs
  class ChatDeleteOldMessages < ::Jobs::Scheduled
    daily at: 0.hours

    def execute(args = {})
      delete_public_channel_messages
      delete_dm_channel_messages
    end

    private

    def delete_public_channel_messages
      return unless valid_day_value?(:chat_channel_retention_days)

      Chat::MessageDestroyer.new.destroy_in_batches(
        Chat::Message.in_public_channel.with_deleted.created_before(
          SiteSetting.chat_channel_retention_days.days.ago,
        ),
      )
    end

    def delete_dm_channel_messages
      return unless valid_day_value?(:chat_dm_retention_days)

      Chat::MessageDestroyer.new.destroy_in_batches(
        Chat::Message.in_dm_channel.with_deleted.created_before(
          SiteSetting.chat_dm_retention_days.days.ago,
        ),
      )
    end

    def valid_day_value?(setting_name)
      (SiteSetting.public_send(setting_name) || 0).positive?
    end
  end
end
