# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module FetchTopic
      class V1 < Actions::Base
        def self.identifier
          "action:fetch_topic"
        end

        def self.configuration_schema
          { topic_id: { type: :string, required: true } }
        end

        def self.output_schema
          {
            topic_id: :integer,
            topic_title: :string,
            topic_raw: :string,
            username: :string,
            tags: :array,
            category_id: :integer,
          }
        end

        def execute_single(context, item:, config:)
          topic = Topic.find(config["topic_id"])
          first_post = topic.first_post

          {
            topic_id: topic.id,
            topic_title: topic.title,
            topic_raw: first_post&.raw,
            username: first_post&.user&.username,
            tags: topic.tags.pluck(:name),
            category_id: topic.category_id,
          }
        end
      end
    end
  end
end
