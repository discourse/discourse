# frozen_string_literal: true

module PageObjects
  module Components
    class CategoryList < PageObjects::Components::Base
      TOPIC_LIST_ITEM_SELECTOR = ".category-list.with-topics .featured-topic"

      def has_category?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("tr[data-category-id='#{category.id}']").filter(visible: true),
        )
      end

      def has_topic?(topic)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(topic_list_item_class(topic)).filter(visible: true),
        )
      end

      def has_no_new_posts_badge?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".new-posts").filter(visible: true),
        )
      end

      def click_category_navigation
        browser_root.locator(".nav-pills .categories").filter(visible: true).click
      end

      def click_logo
        browser_root.locator(".title a").filter(visible: true).click
      end

      def click_new_posts_badge(count: 1)
        browser_root
          .locator(".new-posts")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern("#{count} new"))
          .click
      end

      def click_topic(topic)
        browser_root
          .locator("a")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(topic.title))
          .click
      end

      def category_box(category)
        browser_root.locator("div.category-box[data-category-id='#{category.id}']").filter(
          visible: true,
        )
      end

      def topic_list_item_class(topic)
        "#{TOPIC_LIST_ITEM_SELECTOR}[data-topic-id='#{topic.id}']"
      end
    end
  end
end
