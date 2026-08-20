# frozen_string_literal: true

module PageObjects
  module Pages
    class UserActivityStream < PageObjects::Pages::Base
      def visit_replies(user)
        page.visit("/u/#{user.username_lower}/activity/replies")
        self
      end

      def has_items?(count:)
        page.has_css?(".user-stream-item", count:)
      end

      def scroll_to_bottom
        page.scroll_to(:bottom)
        self
      end

      def scroll_to_item(index)
        page.execute_script(
          "document.querySelectorAll('.user-stream-item')[#{index}].scrollIntoView(true)",
        )
        self
      end

      def open_item(index)
        page.all(".user-stream-item .title a")[index].click
        self
      end

      def scroll_position
        page.evaluate_script("window.scrollY")
      end
    end
  end
end
