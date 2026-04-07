# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicCreated
      class V1 < NodeType
        def self.identifier
          "trigger:topic_created"
        end

        def self.icon
          "plus"
        end

        def self.color_key
          "teal"
        end

        def self.palette_group_id
          "discourse_triggers"
        end

        def self.event_name
          :topic_created
        end

        def self.output_schema
          { topic: Schemas::Topic.fields }
        end

        def initialize(topic, opts = nil, *)
          super(configuration: {})
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
