# frozen_string_literal: true

module PageObjects
  module Pages
    class UserActivityStream < PageObjects::Pages::Base
      def visit_replies(user)
        browser_page
          .goto("/u/#{user.username_lower}/activity/replies")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_items?(count:)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator(".user-stream-item").filter(visible: true),
        )
      end

      def scroll_to_bottom
        browser_page.evaluate("() => window.scrollTo(0, document.scrollingElement.scrollHeight)")
        self
      end

      def scroll_to_item(index)
        browser_page.evaluate(
          "function(arguments) { #{"document.querySelectorAll('.user-stream-item')[#{index}].scrollIntoView(true)"} }",
          arg: [],
        )
        self
      end

      def open_item(index)
        browser_root
          .locator(".user-stream-item .title a")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all[
          index
        ].click
        self
      end

      def scroll_position
        browser_page.evaluate("function(arguments) { return window.scrollY }", arg: [])
      end
    end
  end
end
