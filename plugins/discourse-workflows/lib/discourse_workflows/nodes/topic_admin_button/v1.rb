# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicAdminButton
      class V1 < NodeType
        description(
          name: "trigger:topic_admin_button",
          version: "1.0",
          defaults: {
            icon: "gear",
            color: "cyan",
          },
          group: "discourse_triggers",
          properties: {
            label: {
              type: :string,
              required: true,
            },
            icon: {
              type: :icon,
              required: false,
            },
          },
          capabilities: {
            manually_triggerable: true,
            provides_current_user: true,
          },
        )

        def initialize(topic)
          super(parameters: {})
          @topic = topic
        end

        def valid?
          @topic.present?
        end

        def output
          { topic: topic_data(@topic) }
        end

        private

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
        end
      end
    end
  end
end
