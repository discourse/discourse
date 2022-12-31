# frozen_string_literal: true

module Jobs
  class SendMessageNotifications < ::Jobs::Base
    def execute(args)
      reason = args[:reason]
      valid_reasons = %w[new edit]
      return unless valid_reasons.include?(reason)

      return if (timestamp = args[:timestamp]).blank?

      return if (message = ChatMessage.find_by(id: args[:chat_message_id])).nil?

      if reason == "new"
        Chat::ChatNotifier.new(message, timestamp).notify_new
      elsif reason == "edit"
        Chat::ChatNotifier.new(message, timestamp).notify_edit
      end
    end
  end
end
