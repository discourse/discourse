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

      def has_no_loading_skeleton?
        has_no_css?(".chat-thread__messages .chat-skeleton")
      end

      def type_in_composer(input)
        find(".chat-composer-input--thread").click # makes helper more reliable by ensuring focus is not lost
        find(".chat-composer-input--thread").send_keys(input)
      end

      def fill_composer(input)
        find(".chat-composer-input--thread").click # makes helper more reliable by ensuring focus is not lost
        find(".chat-composer-input--thread").fill_in(with: input)
      end

      def click_composer
        find(".chat-composer-input--thread").click # ensures autocomplete is closed and not masking anything
      end

      def send_message(id, text = nil)
        text = text.chomp if text.present? # having \n on the end of the string counts as an Enter keypress
        fill_composer(text)
        click_send_message(id)
        click_composer
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
