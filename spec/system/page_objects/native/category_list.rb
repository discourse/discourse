# frozen_string_literal: true
module PageObjects
  module Native
    class CategoryList
      def initialize(page)
        @page = page
      end

      def visit
        @page.goto("/categories")
      end

      def featured_topic(topic)
        @page.locator(
          ".category-list.with-topics .featured-topic[data-topic-id='#{topic.id}']:visible",
        )
      end
    end
  end
end
