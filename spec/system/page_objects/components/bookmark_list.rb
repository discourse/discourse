# frozen_string_literal: true

module PageObjects
  module Components
    class BookmarkList < PageObjects::Components::Base
      SELECTOR = ".bookmark-list"

      def has_assignee?(topic, assignee)
        contain_text([browser_text_pattern(assignee.username)], useInnerText: true).matches?(
          bookmark_row(topic).locator(".assigned-to").filter(visible: true),
        )
      end

      def has_no_assignment?(topic)
        have_count(0).matches?(
          bookmark_row(topic)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".assigned-to")
            .filter(visible: true),
        )
      end

      private

      def bookmark_row(topic)
        browser_root
          .locator("#{SELECTOR} .bookmark-list-item")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(topic.title))
      end
    end
  end
end
