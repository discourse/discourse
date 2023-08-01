# frozen_string_literal: true

module Chat
  class DuplicateMessageValidator
    attr_reader :chat_message

    def initialize(chat_message)
      @chat_message = chat_message
    end

    def validate
      return if SiteSetting.chat_duplicate_message_sensitivity.zero?
      matrix =
        DuplicateMessageValidator.sensitivity_matrix(SiteSetting.chat_duplicate_message_sensitivity)

      # Check if the length of the message is too short to check for a duplicate message
      return if chat_message.message.length < matrix[:min_message_length]

      # Check if there are enough users in the channel to check for a duplicate message
      return if (chat_message.chat_channel.user_count || 0) < matrix[:min_user_count]

      # Check if the same duplicate message has been posted in the last N seconds by any user
      if !chat_message
           .chat_channel
           .chat_messages
           .where("created_at > ?", matrix[:min_past_seconds].seconds.ago)
           .where(message: chat_message.message)
           .exists?
        return
      end

      chat_message.errors.add(:base, I18n.t("chat.errors.duplicate_message"))
    end

    def self.sensitivity_matrix(sensitivity)
      {
        # 0.1 sensitivity = 100 users and 1.0 sensitivity = 5 users.
        min_user_count: (-1.0 * 105.5 * sensitivity + 110.55).to_i,
        # 0.1 sensitivity = 30 chars and 1.0 sensitivity = 10 chars.
        min_message_length: (-1.0 * 22.2 * sensitivity + 32.22).to_i,
        # 0.1 sensitivity = 10 seconds and 1.0 sensitivity = 60 seconds.
        min_past_seconds: (55.55 * sensitivity + 4.5).to_i,
      }
    end
  end
end
