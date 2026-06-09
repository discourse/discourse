# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicCategoryChanged
      class V1 < NodeType
        description(
          name: "trigger:topic_category_changed",
          version: "1.0",
          defaults: {
            icon: "folder-open",
            color: "deep-orange",
          },
          group: "discourse_triggers",
          events: [:topic_category_changed],
        )

        def initialize(topic, old_category)
          super(parameters: {})
          @topic = topic
          @old_category = old_category
        end

        def valid?
          @topic.present? && @old_category.present?
        end

        def output
          { topic: topic_data(@topic), old_category_id: @old_category.id }
        end

        private

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
        end
      end
    end
  end
end
