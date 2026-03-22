# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    class StaleTopic < Base
      def self.identifier
        "trigger:stale_topic"
      end

      def self.output_schema
        { topic_id: :integer, topic_title: :string, tags: :array, category_id: :integer }
      end

      def self.configuration_schema
        { hours: { type: :integer, required: true, default: 24, min: 1 } }
      end

      def initialize(topic)
        @topic = topic
      end

      def output
        {
          topic_id: @topic.id,
          topic_title: @topic.title,
          tags: @topic.tags.pluck(:name),
          category_id: @topic.category_id,
        }
      end
    end
  end
end
