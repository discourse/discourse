# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module StaleTopic
      class V1 < NodeType
        def self.identifier
          "trigger:stale_topic"
        end

        def self.icon
          "clock"
        end

        def self.color_key
          "deep-orange"
        end

        def self.palette_group_id
          "discourse_triggers"
        end

        def self.output_schema
          { topic: Schemas::Topic.fields }
        end

        def self.configuration_schema
          { hours: { type: :integer, required: true, default: 24, min: 1 } }
        end

        def initialize(topic)
          super(configuration: {})
          @topic = topic
        end

        def output
          { topic: Schemas::Topic.resolve(@topic) }
        end
      end
    end
  end
end
