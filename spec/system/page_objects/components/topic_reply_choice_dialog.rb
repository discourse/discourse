# frozen_string_literal: true

module PageObjects
  module Components
    class TopicReplyChoiceDialog < PageObjects::Components::Dialog
      def has_reply_on_original_topic?(topic)
        find("#{reply_on_original_selector}").has_content?(topic.title)
      end

      def reply_on_original_selector
        ".btn-reply-on-original"
      end

      def click_reply_on_original
        find("#{reply_on_original_selector}").click
      end

      def has_reply_here_topic?(topic)
        find("#{reply_here_selector}").has_content?(topic.title)
      end

      def reply_here_selector
        ".btn-reply-here"
      end

      def click_reply_here
        find("#{reply_here_selector}").click
      end

      def click_cancel
        find(".btn-reply-where__cancel").click
      end
    end
  end
end
