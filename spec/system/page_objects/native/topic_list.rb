# frozen_string_literal: true
module PageObjects
  module Native
    class TopicList
      def initialize(page)
        @page = page
      end

      def visit_latest
        @page.goto("/latest")
      end

      def visit_new
        @page.goto("/new")
      end

      def topics
        @page.locator(".topic-list-body .topic-list-item:visible")
      end

      def all_toggle
        @page.locator(".topics-replies-toggle.--all:visible")
      end

      def topics_toggle
        @page.locator(".topics-replies-toggle.--topics:visible")
      end

      def replies_toggle
        @page.locator(".topics-replies-toggle.--replies:visible")
      end

      def new_topics_alert
        @page.locator(".show-more.has-topics:visible")
      end

      def highlighted_topic(topic)
        @page.locator(
          ".topic-list-body .topic-list-item[data-topic-id='#{topic.id}'][data-test-was-highlighted]:visible",
        )
      end

      def topic_checkbox(topic)
        @page.locator(
          ".topic-list-body .topic-list-item[data-topic-id='#{topic.id}'] input#bulk-select-#{topic.id}:visible",
        )
      end

      def open_topic(topic)
        @page.locator(
          ".topic-list-body .topic-list-item[data-topic-id='#{topic.id}'] a.raw-topic-link",
        ).click
      end

      def go_back
        @page.go_back
      end

      def bulk_select
        @page.locator("button.bulk-select:visible")
      end

      def bulk_actions
        @page.locator("button.bulk-select-topics-dropdown-trigger:visible")
      end

      def pinned_icon
        @page.locator(".topic-list-item .d-icon-thumbtack:not(.unpinned):visible")
      end

      def unpinned_icon
        @page.locator(".topic-list-item .d-icon-thumbtack.unpinned:visible")
      end

      def click_pin
        @page.locator(".topic-list-item .d-icon-thumbtack").click
      end

      def return_to_list
        @page.locator("#site-logo").click
      end

      def visited_title
        @page.locator(".topic-list .topic-list-item.visited a.title:visible")
      end

      def unvisited_title
        @page.locator(".topic-list .topic-list-item:not(.visited) a.title:visible")
      end
    end
  end
end
