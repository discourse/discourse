# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module TopicCategoryChanged
      class V1 < Triggers::Base
        def self.identifier
          "trigger:topic_category_changed"
        end

        def self.icon
          "folder-open"
        end

        def self.color_key
          "deep-orange"
        end

        def self.event_name
          :topic_category_changed
        end

        def self.output_schema
          { topic: Schemas::Topic.fields, old_category_id: :integer }
        end

        def initialize(topic, old_category)
          @topic = topic
          @old_category = old_category
        end

        def valid?
          @topic.present? && @old_category.present?
        end

        def output
          { topic: Schemas::Topic.resolve(@topic), old_category_id: @old_category.id }
        end
      end
    end
  end
end
