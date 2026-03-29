# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module TopicTagChanged
      class V1 < Triggers::Base
        def self.identifier
          "trigger:topic_tag_changed"
        end

        def self.icon
          "tag"
        end

        def self.color_key
          "deep-orange"
        end

        def self.event_name
          :topic_tags_changed
        end

        def self.output_schema
          {
            topic: Schemas::Topic.fields,
            old_tags: :array,
            new_tags: :array,
            added_tags: :array,
            removed_tags: :array,
          }
        end

        def initialize(topic, payload = {})
          @topic = topic
          @old_tag_names = payload[:old_tag_names] || []
          @new_tag_names = payload[:new_tag_names] || []
          @user = payload[:user]
        end

        def valid?
          @topic.present?
        end

        def output
          {
            topic: Schemas::Topic.resolve(@topic),
            old_tags: @old_tag_names,
            new_tags: @new_tag_names,
            added_tags: @new_tag_names - @old_tag_names,
            removed_tags: @old_tag_names - @new_tag_names,
          }
        end
      end
    end
  end
end
