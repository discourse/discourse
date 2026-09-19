# frozen_string_literal: true

module PageObjects
  module Components
    class BookmarkList < PageObjects::Components::Base
      SELECTOR = ".bookmark-list"

      def has_assignee?(topic, assignee)
        bookmark_row(topic).has_css?(".assigned-to", text: assignee.username)
      end

      def has_no_assignment?(topic)
        bookmark_row(topic).has_no_css?(".assigned-to")
      end

      private

      def bookmark_row(topic)
        page.find("#{SELECTOR} .bookmark-list-item", text: topic.title)
      end
    end
  end
end
