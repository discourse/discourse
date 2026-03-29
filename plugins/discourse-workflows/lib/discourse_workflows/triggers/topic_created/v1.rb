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
          { topic: Schemas::Topic.fields }
        end

        def initialize(topic, opts = nil, *)
          @topic = topic
          @opts = opts
        end

        def valid?
          @topic.present? && !skip_workflows?(@opts)
        end

        def output
          { topic: Schemas::Topic.resolve(@topic) }
        end
      end
    end
  end
end
