# frozen_string_literal: true

module PageObjects
  module Components
    class AiChatMessage < Base
      def has_model?(message, name)
        page.has_css?(
          ".chat-message-container[data-id='#{message.id}'] .ai-chat-message__model",
          text: name,
        )
      end

      def has_no_model?(message)
        page.has_no_css?(".chat-message-container[data-id='#{message.id}'] .ai-chat-message__model")
      end
    end
  end
end
