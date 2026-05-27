# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module StaleTopic
      class V1 < NodeType
        description(
          name: "trigger:stale_topic",
          version: "1.0",
          defaults: {
            icon: "clock",
            color: "deep-orange",
          },
          group: "discourse_triggers",
          properties: {
            hours: {
              type: :integer,
              required: true,
              default: 24,
              min: 1,
            },
            category_id: {
              type: :integer,
              required: false,
              ui: {
                control: :category,
              },
            },
            tag_names: {
              type: :string,
              required: false,
              ui: {
                control: :tags,
              },
            },
          },
          capabilities: {
            manually_triggerable: true,
          },
        )

        MAX_TOPICS_PER_RUN = 100

        def self.trigger_data_for(trigger_ctx)
          hours = trigger_ctx.get_node_parameter("hours", 24)
          category_id = trigger_ctx.get_node_parameter("category_id").presence&.to_i
          tag_names = normalize_tag_names(trigger_ctx.get_node_parameter("tag_names"))

          stale_topics(
            hours: hours,
            category_id: category_id,
            tag_names: tag_names,
            limit: MAX_TOPICS_PER_RUN,
          ).map { |topic| { topic: topic_data(topic) } }
        end

        def self.stale_topics(hours:, category_id: nil, tag_names: [], limit:)
          threshold = hours.to_i.clamp(1..).hours.ago

          scope =
            ::Topic
              .where("GREATEST(topics.created_at, topics.last_posted_at) < ?", threshold)
              .where(closed: false, archived: false, visible: true)
              .where("topics.archetype = ?", Archetype.default)
              .includes(first_post: :user)

          scope = scope.where(category_id: category_id) if category_id
          scope = scope.joins(:tags).where(tags: { name: tag_names }).distinct if tag_names.any?

          scope.limit(limit).to_a
        end

        def self.topic_data(topic)
          MultiJson.load(
            TopicListItemSerializer.new(
              topic,
              scope: Discourse.system_user.guardian,
              root: false,
            ).to_json,
          ).deep_symbolize_keys
        end
      end
    end
  end
end
