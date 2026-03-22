# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    class TopicCategoryChanged < Base
      def self.identifier
        "trigger:topic_category_changed"
      end

      def self.event_name
        :topic_category_changed
      end

      def self.output_schema
        {
          topic_id: :integer,
          topic_title: :string,
          tags: :array,
          category_id: :integer,
          old_category_id: :integer,
          user_id: :integer,
          username: :string,
        }
      end

      def initialize(topic, old_category)
        @topic = topic
        @old_category = old_category
      end

      def valid?
        @topic.present? && @old_category.present?
      end

      def output
        {
          topic_id: @topic.id,
          topic_title: @topic.title,
          tags: @topic.tags.pluck(:name),
          category_id: @topic.category_id,
          old_category_id: @old_category.id,
          user_id: @topic.user_id,
          username: @topic.user&.username,
        }
      end
    end
  end
end
