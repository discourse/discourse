# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicClosed
      class V1 < NodeType
        def self.identifier
          "trigger:topic_closed"
        end

        def self.icon
          "lock"
        end

        def self.color
          "grey"
        end

        def self.group
          "discourse_triggers"
        end

        def self.event_name
          :topic_status_updated
        end

        def self.output_schema
          { topic: Schemas::Topic.fields }
        end

        def initialize(topic, status, enabled)
          super(configuration: {})
          @topic = topic
          @status = status
          @enabled = enabled
        end

        def valid?
          @status.to_s == "closed" && @enabled
        end

        def output
          { topic: Schemas::Topic.resolve(@topic) }
        end
      end
    end
  end
end
