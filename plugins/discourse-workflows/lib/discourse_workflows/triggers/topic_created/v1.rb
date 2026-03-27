# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module TopicCreated
      class V1 < Triggers::Base
        def self.identifier
          "trigger:topic_created"
        end

        def self.icon
          "plus"
        end

        def self.color_key
          "teal"
        end

        def self.event_name
          :topic_created
        end

        def self.output_schema
          {
            topic_id: :integer,
            topic_title: :string,
            topic_raw: :string,
            tags: :array,
            category_id: :integer,
            user_id: :integer,
            username: :string,
            archetype: :string,
          }
        end

        def initialize(topic, opts = nil, *)
          @topic = topic
          @opts = opts
        end

        def valid?
          @topic.present? && !skip_workflows?(@opts)
        end

        def output
          {
            topic_id: @topic.id,
            topic_title: @topic.title,
            topic_raw: @topic.first_post&.raw,
            tags: @topic.tags.pluck(:name),
            category_id: @topic.category_id,
            user_id: @topic.user_id,
            username: @topic.user&.username,
            archetype: @topic.archetype,
          }
        end
      end
    end
  end
end
