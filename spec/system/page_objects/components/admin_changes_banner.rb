# frozen_string_literal: true

module PageObjects
  module Components
    class AdminChangesBanner < Base
      def visible?
        have_count(0).does_not_match?(browser_root.locator(selector).filter(visible: true))
      end

      def hidden?
        have_count(0).matches?(browser_root.locator(selector).filter(visible: true))
      end

      def element
        browser_root.locator(selector).filter(visible: true)
      end

      def click_save
        element.locator(".btn-primary").filter(visible: true).click
      end

      def click_discard
        element.locator(".btn-default").filter(visible: true).click
      end

      def has_label?(label)
        contain_text([browser_text_pattern(label)], useInnerText: true).matches?(
          element.locator(".admin-changes-banner__main-label").filter(visible: true),
        )
      end

      private

      def selector
        ".admin-changes-banner"
      end
    end
  end
end
