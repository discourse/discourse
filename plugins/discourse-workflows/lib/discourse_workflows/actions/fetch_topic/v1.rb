# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module FetchTopic
      class V1 < Actions::Base
        def self.identifier
          "action:fetch_topic"
        end

        def self.icon
          "download"
        end

        def self.color_key
          "light-blue"
        end

        def self.configuration_schema
          { topic_id: { type: :string, required: true } }
        end

        def self.output_schema
          { topic: Schemas::Topic.fields }
        end

        def execute_single(_context, item:, config:)
          topic = Topic.find(config["topic_id"])
          { topic: Schemas::Topic.resolve(topic) }
        end
      end
    end
  end
end
