# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatChannel < PageObjects::Pages::Base
      def type_in_composer(input)
        find(".chat-composer-input").send_keys(input)
      end

      def fill_composer(input)
        find(".chat-composer-input").fill_in(with: input)
      end

      def click_send_message
        find(".chat-composer .send-btn").click
      end

      def message_by_id(id)
        find(".chat-message-container[data-id=\"#{id}\"]")
      end

      def has_no_loading_skeleton?
        has_no_css?(".chat-skeleton")
      end

      def has_message?(text: nil, id: nil)
        if text
          has_css?(".chat-message-text", text: text)
        elsif id
          has_css?(".chat-message-container[data-id=\"#{id}\"]", wait: 10)
        end
      end
    end
  end
end
