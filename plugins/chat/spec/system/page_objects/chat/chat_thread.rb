# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatThread < PageObjects::Pages::Base
      def header
        find(".chat-thread__header")
      end

      def omu
        header.find(".chat-thread__omu")
      end

      def has_header_content?(content)
        header.has_content?(content)
      end

      def thread_selector_by_id(id)
        ".chat-thread[data-id=\"#{id}\"]"
      end

      def fill_composer(id, input)
        find(thread_selector_by_id(id)).find(".chat-composer-input").fill_in(with: input)
      end

      def click_send_message(id)
        find(thread_selector_by_id(id)).find(".chat-composer .send-btn:enabled").click
      end

      def has_message?(thread_id, text: nil, id: nil)
        if text
          find(thread_selector_by_id(thread_id)).has_css?(".chat-message-text", text: text)
        elsif id
          find(thread_selector_by_id(thread_id)).has_css?(
            ".chat-message-container[data-id=\"#{id}\"]",
            wait: 10,
          )
        end
      end
    end
  end
end
