# frozen_string_literal: true

module PageObjects
  module Components
    class CategoryList < PageObjects::Components::Base
      TOPIC_LIST_ITEM_SELECTOR = ".category-list.with-topics .featured-topic"

      def has_category?(category)
        page.has_css?("tr[data-category-id='#{category.id}']")
      end

      def has_topic?(topic)
        page.has_css?(topic_list_item_class(topic))
      end

      def has_no_new_posts_badge?
        page.has_no_css?(".new-posts")
      end

      def click_category_navigation
        page.find(".nav-pills .categories").click
      end

      def click_logo
        page.find(".title a").click
      end

      def click_new_posts_badge(count: 1)
        page.find(".new-posts", text: "#{count} new").click
      end

      def click_topic(topic)
        page.find("a", text: topic.title).click
      end

      def topic_list_item_class(topic)
        "#{TOPIC_LIST_ITEM_SELECTOR}[data-topic-id='#{topic.id}']"
      end
    end
  end
end
