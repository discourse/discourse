# frozen_string_literal: true
module PageObjects
  module Native
    class Topic
      def initialize(page)
        @page = page
      end

      def visit(topic)
        @page.goto(topic.relative_url)
      end

      def title
        @page.locator("h1 .fancy-title:visible")
      end

      def suggested_topic(topic)
        @page.locator("#suggested-topics .topic-list-item[data-topic-id='#{topic.id}']:visible")
      end

      def new_topic_badge(topic)
        @page.locator("[data-topic-id='#{topic.id}'] a.badge-notification.new-topic:visible")
      end

      def unread_posts_badge(topic)
        @page.locator("[data-topic-id='#{topic.id}'] a.badge-notification.unread-posts:visible")
      end

      def first_post
        @page.locator("#post_1:visible")
      end
    end
  end
end
