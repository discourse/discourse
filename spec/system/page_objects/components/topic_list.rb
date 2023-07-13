# frozen_string_literal: true

module PageObjects
  module Components
    class TopicList < PageObjects::Components::Base
      TOPIC_LIST_BODY_SELECTOR = ".topic-list-body"
      TOPIC_LIST_ITEM_SELECTOR = "#{TOPIC_LIST_BODY_SELECTOR} .topic-list-item"

      def topic_list
        TOPIC_LIST_BODY_SELECTOR
      end

      def has_topics?(count: nil)
        if count.nil?
          page.has_css?(TOPIC_LIST_ITEM_SELECTOR)
        else
          page.has_css?(TOPIC_LIST_ITEM_SELECTOR, count: count)
        end
      end

      def has_no_topics?
        page.has_no_css?(TOPIC_LIST_ITEM_SELECTOR)
      end

      def has_topic?(topic)
        page.has_css?(topic_list_item_class(topic))
      end

      def has_no_topic?(topic)
        page.has_no_css?(topic_list_item_class(topic))
      end

      def visit_topic_with_title(title)
        find("#{TOPIC_LIST_BODY_SELECTOR} a", text: title).click
      end

      def visit_topic(topic)
        find("#{topic_list_item_class(topic)} a.raw-topic-link").click
      end

      private

      def topic_list_item_class(topic)
        "#{TOPIC_LIST_ITEM_SELECTOR}[data-topic-id='#{topic.id}']"
      end
    end
  end
end
