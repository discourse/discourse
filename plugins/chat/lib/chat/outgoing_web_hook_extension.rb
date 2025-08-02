# frozen_string_literal: true

module Chat
  module OutgoingWebHookExtension
    def self.prepended(base)
      def base.enqueue_chat_message_hooks(event, payload, opts = {})
        if active_web_hooks(event).exists?
          WebHook.enqueue_hooks(:chat_message, event, payload: payload, **opts)
        end
      end
    end
  end
end
