# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module TopicAdminButton
      class V1 < Triggers::Base
        def self.identifier
          "trigger:topic_admin_button"
        end

        def self.icon
          "gear"
        end

        def self.color_key
          "cyan"
        end

        def self.manually_triggerable?
          true
        end

        def self.output_schema
          { topic: Schemas::Topic.fields }
        end

        def self.configuration_schema
          { label: { type: :string, required: true }, icon: { type: :icon, required: false } }
        end

        def initialize(topic)
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
