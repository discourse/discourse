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
        find(".chat-thread .chat-composer__input").click # makes helper more reliable by ensuring focus is not lost
        find(".chat-thread .chat-composer__input").send_keys(input)
      end

      def fill_composer(input)
        find(".chat-thread .chat-composer__input").click # makes helper more reliable by ensuring focus is not lost
        find(".chat-thread .chat-composer__input").fill_in(with: input)
      end

      def click_composer
        find(".chat-thread .chat-composer__input").click # ensures autocomplete is closed and not masking anything
      end

      def send_message(id, text = nil)
        text = text.chomp if text.present? # having \n on the end of the string counts as an Enter keypress
        fill_composer(text)
        click_send_message(id)
        click_composer
      end

      def click_send_message(id)
        find(thread_selector_by_id(id)).find(
          ".chat-composer--send-enabled .chat-composer__send-btn",
        ).click
      end

      def has_message?(thread_id, text: nil, id: nil)
        check_message_presence(thread_id, exists: true, text: text, id: id)
      end

      def has_no_message?(thread_id, text: nil, id: nil)
        check_message_presence(thread_id, exists: false, text: text, id: id)
      end

      def check_message_presence(thread_id, exists: true, text: nil, id: nil)
        css_method = exists ? :has_css? : :has_no_css?
        if text
          find(thread_selector_by_id(thread_id)).send(
            css_method,
            ".chat-message-text",
            text: text,
            wait: 5,
          )
        elsif id
          find(thread_selector_by_id(thread_id)).send(
            css_method,
            ".chat-message-container[data-id=\"#{id}\"]",
            wait: 10,
          )
        end
      end

      def hover_message(message)
        message_by_id(message.id).hover
      end

      def message_by_id(id)
        find(message_by_id_selector(id))
      end

      def message_by_id_selector(id)
        ".chat-thread .chat-messages-container .chat-message-container[data-id=\"#{id}\"]"
      end
    end
  end
end
