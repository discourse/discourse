# frozen_string_literal: true

class Chat::ChatChannelDestroyer < ServiceBase
  attr_reader :channel

  def initialize(guardian, channel)
    super(guardian)
    @channel = channel
  end

  def execute(name_confirmation:)
    execute_service_call do
      guardian.ensure_can_delete_chat_channel!

      if channel.title(guardian.user).downcase != name_confirmation
        fail_validation!(I18n.t("chat.errors.delete_channel_name_confirmation_invalid"))
      end

      begin
        delete_channel
      rescue ActiveRecord::Rollback
        fail_unexpected!(uncaught_error_message)
      end

      enqueue_job(:chat_channel_delete, chat_channel_id: channel.id)
    end
  end

  def uncaught_error_message
    I18n.t("chat.errors.delete_channel_failed")
  end

  private

  def delete_channel
    ChatChannel.transaction do
      channel.update!(slug: deleted_slug)
      channel.trash!(guardian.user)
      log_staff_action(
        "chat_channel_delete",
        { chat_channel_id: channel.id, chat_channel_name: channel.title(guardian.user) },
      )
    end
  end

  # Prevent collisions with newly created channels with the same slug
  def deleted_slug
    "#{Time.now.strftime("%Y%m%d-%H%M")}-#{channel.slug}-deleted".truncate(
      SiteSetting.max_topic_title_length,
      omission: "",
    )
  end
end
