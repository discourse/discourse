# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicAdminButton
      class V1 < NodeType
        def self.identifier
          "trigger:topic_admin_button"
        end

        def self.icon
          "gear"
        end

        def self.color
          "cyan"
        end

        def self.group
          "discourse_triggers"
        end

        def self.manually_triggerable?
          true
        end

        def self.provides_current_user?
          true
        end

        def self.output_schema
          { topic: Schemas::Topic.fields }
        end

        def self.property_schema
          { label: { type: :string, required: true }, icon: { type: :icon, required: false } }
        end

        def initialize(topic)
          super(configuration: {})
          @topic = topic
        end

        def valid?
          @topic.present?
        end

        def output
          { topic: Schemas::Topic.resolve(@topic) }
        end
      end
    end
  end
end
