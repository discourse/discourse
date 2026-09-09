# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicModeration
      class V1 < NodeType
        OPERATIONS = %w[unlist_topic].freeze

        description(
          name: "action:topic_moderation",
          version: "1.0",
          defaults: {
            icon: "shield-halved",
            color: "red",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [{ schema: Schema::TOPIC_LIST_ITEM_SCHEMA }],
          properties: {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "unlist_topic",
              ui: {
                expression: false,
              },
            },
            topic_id: {
              type: :string,
              required: true,
            },
            actor_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :actor,
              },
            },
          },
        )

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              operation =
                exec_ctx.get_node_parameter("operation", item_index, default: "unlist_topic")
              topic_id = exec_ctx.get_node_parameter("topic_id", item_index)

              wrap(process(exec_ctx, operation, topic_id, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, operation, topic_id, item_index)
          if !OPERATIONS.include?(operation)
            raise_node_error!(
              I18n.t("discourse_workflows.errors.unknown_operation", operation: operation),
            )
          end

          topic = ::Topic.find(topic_id)
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          actor.guardian.ensure_can_toggle_topic_visibility!(topic)

          TopicStatusUpdater.new(topic, actor).update!(
            "visible",
            false,
            visibility_reason_id: ::Topic.visibility_reasons[:manually_unlisted],
          )

          topic.reload
          { topic: exec_ctx.serialize_topic(topic, guardian: actor.guardian) }
        end
      end
    end
  end
end
