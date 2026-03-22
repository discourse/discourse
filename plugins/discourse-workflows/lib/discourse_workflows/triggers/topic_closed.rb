# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    class TopicClosed < Base
      def self.identifier
        "trigger:topic_closed"
      end

      def self.event_name
        :topic_status_updated
      end

      def self.output_schema
        { topic_id: :integer, topic_title: :string, tags: :array, category_id: :integer }
      end

      def initialize(topic, status, enabled)
        @topic = topic
        @status = status
        @enabled = enabled
      end

      def valid?
        @status.to_s == "closed" && @enabled
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
