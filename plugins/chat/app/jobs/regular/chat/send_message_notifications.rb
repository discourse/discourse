# frozen_string_literal: true

module Jobs
  module Chat
    class SendMessageNotifications < ::Jobs::Base
      def execute(args)
        reason = args[:reason]
        valid_reasons = %w[new edit]
        return if valid_reasons.exclude?(reason)

        return if (timestamp = args[:timestamp]).blank?

        return if (message = ::Chat::Message.find_by(id: args[:chat_message_id])).nil?

        if reason == "new"
          ::Chat::Notifier.new(message, timestamp).notify_new
        elsif reason == "edit"
          ::Chat::Notifier.new(message, timestamp).notify_edit
        end
      end
    end
  end
end
