# frozen_string_literal: true

module PageObjects
  module Components
    class TopicList < PageObjects::Components::Base
      def topic_list
        ".topic-list-body"
      end

      def visit_topic_with_title(title)
        find(".topic-list-body a", text: title).click
      end
    end
  end
end
