# frozen_string_literal: true

module PageObjects
  module Components
    class TopicReplyChoiceDialog < PageObjects::Components::Dialog
      def has_reply_on_original_topic?(topic)
        PlaywrightMatchers.contain_text(
          browser_text_pattern(topic.title),
          useInnerText: true,
        ).matches?(browser_root.locator("#{reply_on_original_selector}").filter(visible: true))
      end

      def reply_on_original_selector
        ".btn-reply-on-original"
      end

      def click_reply_on_original
        browser_root.locator("#{reply_on_original_selector}").filter(visible: true).click
      end

      def has_reply_here_topic?(topic)
        PlaywrightMatchers.contain_text(
          browser_text_pattern(topic.title),
          useInnerText: true,
        ).matches?(browser_root.locator("#{reply_here_selector}").filter(visible: true))
      end

      def reply_here_selector
        ".btn-reply-here"
      end

      def click_reply_here
        browser_root.locator("#{reply_here_selector}").filter(visible: true).click
      end

      def click_cancel
        browser_root.locator(".btn-reply-where__cancel").filter(visible: true).click
      end
    end
  end
end
