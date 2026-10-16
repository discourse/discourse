# frozen_string_literal: true

module PageObjects
  module Pages
    class GroupActivityPosts < PageObjects::Pages::Base
      def visit(group)
        browser_page
          .goto("/g/#{group.name}/activity/posts")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_user_stream_item?(count:)
        have_count(count).matches?(browser_root.locator(".post-list-item").filter(visible: true))
      end

      def scroll_to_last_item
        browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: [])
          document.querySelector('.post-list-item:last-of-type').scrollIntoView(true);
        JS
      end
    end
  end
end
