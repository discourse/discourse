# frozen_string_literal: true

module PageObjects
  module Components
    class LiveRoomChatPanel < PageObjects::Components::Base
      SELECTOR = ".live-chat"

      def compose(message)
        find("#{SELECTOR} .chat-composer__input").fill_in(with: message)
        self
      end

      def send_message
        find("#{SELECTOR} .chat-composer__input").send_keys(:enter)
        self
      end

      def attach(path)
        attach_file("thread-file-uploader", path, make_visible: true)
        self
      end

      def has_toolbar?
        has_css?("#{SELECTOR} .chat-composer-dropdown__trigger-btn")
      end

      def has_thread?
        has_css?("#{SELECTOR} .chat-thread")
      end

      def has_message?(text)
        has_css?("#{SELECTOR} .chat-message-text", text: text)
      end

      def has_draft?(text)
        has_field?("thread-composer", with: text)
      end

      def has_attachment?
        has_css?("#{SELECTOR} .chat-composer-upload") &&
          has_css?("#{SELECTOR} .chat-composer-button.-send:not([disabled])")
      end

      def has_image_message?
        has_css?("#{SELECTOR} .chat-message-text img")
      end
    end
  end
end
