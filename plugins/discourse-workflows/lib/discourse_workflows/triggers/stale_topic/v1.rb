# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module StaleTopic
      class V1 < Triggers::Base
        def self.identifier
          "trigger:stale_topic"
        end

        def self.icon
          "clock"
        end

        def self.color_key
          "deep-orange"
        end

        def self.output_schema
          { topic: Schemas::Topic.fields }
        end

        def self.configuration_schema
          { hours: { type: :integer, required: true, default: 24, min: 1 } }
        end

        def initialize(topic)
          @topic = topic
        end

        def output
          { topic: Schemas::Topic.resolve(@topic) }
        end
      end
    end
  end
end
