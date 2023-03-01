# frozen_string_literal: true

module PageObjects
  module Components
    class TopicList < PageObjects::Components::Base
      TOPIC_LIST_BODY_CLASS = ".topic-list-body"

      def topic_list
        TOPIC_LIST_BODY_CLASS
      end

      def has_topic?(topic)
        page.has_css?(topic_list_item_class(topic))
      end

      def has_no_topic?(topic)
        page.has_no_css?(topic_list_item_class(topic))
      end

      def visit_topic_with_title(title)
        find(".topic-list-body a", text: title).click
      end

      private

      def topic_list_item_class(topic)
        "#{TOPIC_LIST_BODY_CLASS} .topic-list-item[data-topic-id='#{topic.id}']"
      end
    end
  end
end
