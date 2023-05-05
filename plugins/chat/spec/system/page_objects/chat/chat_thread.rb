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

      def close
        header.find(".chat-thread__close").click
      end

      def has_header_content?(content)
        header.has_content?(content)
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

      def send_message(text = nil)
        text = text.chomp if text.present? # having \n on the end of the string counts as an Enter keypress
        fill_composer(text)
        click_send_message
        click_composer
      end

      def click_send_message
        find(".chat-thread .chat-composer.is-send-enabled .chat-composer__send-btn").click
      end

      def has_message?(text: nil, id: nil, thread_id: nil)
        check_message_presence(exists: true, text: text, id: id, thread_id: thread_id)
      end

      def has_no_message?(text: nil, id: nil, thread_id: nil)
        check_message_presence(exists: false, text: text, id: id, thread_id: thread_id)
      end

      def check_message_presence(exists: true, text: nil, id: nil, thread_id: nil)
        css_method = exists ? :has_css? : :has_no_css?
        selector = thread_id ? ".chat-thread[data-id=\"#{thread_id}\"]" : ".chat-thread"
        if text
          find(selector).send(css_method, ".chat-message-text", text: text, wait: 5)
        elsif id
          find(selector).send(css_method, ".chat-message-container[data-id=\"#{id}\"]", wait: 10)
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

      def has_deleted_message?(message, count: 1)
        has_css?(
          ".chat-thread .chat-message-container[data-id=\"#{message.id}\"] .chat-message-deleted",
          text: I18n.t("js.chat.deleted", count: count),
        )
      end
    end
  end
end
