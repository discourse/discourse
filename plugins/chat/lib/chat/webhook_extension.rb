# frozen_string_literal: true

module Chat
  module WebhookExtension
    def self.prepended(base)
      def base.enqueue_chat_message_hooks(event, payload = nil)
        if active_web_hooks("chat_message").exists?
          WebHook.enqueue_hooks(:chat_message, event, payload: payload)
        end
      end
    end
  end
end
