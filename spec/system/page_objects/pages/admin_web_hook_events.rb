# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWebHookEvents < PageObjects::Pages::Base
      def visit(id)
        browser_page
          .goto("/admin/api/web_hooks/#{id}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def click_filter_all
        browser_root
          .locator(".select-kit-header")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern("All Events"))
          .click
      end

      def click_filter_delivered
        browser_root
          .locator(".select-kit-row")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern("Delivered"))
          .click
      end

      def click_filter_failed
        browser_root
          .locator(".select-kit-row")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern("Failed"))
          .click
      end

      def has_web_hook_event?(id)
        contain_text([browser_text_pattern(id)], useInnerText: true).matches?(
          browser_root.locator("li .event-id").filter(visible: true),
        )
      end

      def has_no_web_hook_event?(id)
        contain_text([browser_text_pattern(id)], useInnerText: true).does_not_match?(
          browser_root.locator("li .event-id").filter(visible: true),
        )
      end
    end
  end
end
