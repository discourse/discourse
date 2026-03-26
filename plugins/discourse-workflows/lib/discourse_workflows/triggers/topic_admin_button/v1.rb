# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module TopicAdminButton
      class V1 < Triggers::Base
        def self.identifier
          "trigger:topic_admin_button"
        end

        def self.manually_triggerable?
          true
        end

        def self.output_schema
          {
            topic_id: :integer,
            topic_title: :string,
            topic_raw: :string,
            tags: :array,
            category_id: :integer,
            user_id: :integer,
            username: :string,
            archetype: :string,
          }
        end

        def self.configuration_schema
          {
            label: {
              type: :string,
              required: true,
            },
            icon: {
              type: :string,
              required: false,
              default: "gear",
            },
          }
        end

        def initialize(topic)
          @topic = topic
        end

        def valid?
          @topic.present?
        end

        def output
          {
            topic_id: @topic.id,
            topic_title: @topic.title,
            topic_raw: @topic.first_post&.raw,
            tags: @topic.tags.pluck(:name),
            category_id: @topic.category_id,
            user_id: @topic.user_id,
            username: @topic.user&.username,
            archetype: @topic.archetype,
          }
        end
      end
    end
  end
end
