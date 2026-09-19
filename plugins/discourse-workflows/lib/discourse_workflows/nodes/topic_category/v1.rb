# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicCategory
      class V1 < NodeType
        description(
          name: "action:topic_category",
          version: "1.0",
          defaults: {
            icon: "folder-open",
            color: "deep-orange",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [
            {
              schema: {
                "$schema" => Schema::DRAFT_URI,
                "type" => "object",
                "properties" => {
                  "topic_id" => {
                    "type" => "integer",
                  },
                  "category_id" => {
                    "type" => "integer",
                  },
                  "old_category_id" => {
                    "type" => "integer",
                  },
                },
              },
            },
          ],
          properties: {
            topic_id: {
              type: :string,
              required: true,
            },
            category_id: {
              type: :integer,
              required: false,
              ui: {
                control: :category,
              },
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
              config = {
                "topic_id" => exec_ctx.get_node_parameter("topic_id", item_index),
                "category_id" => exec_ctx.get_node_parameter("category_id", item_index),
              }

              wrap(process(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, config, item_index)
          topic = ::Topic.find(config["topic_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          guardian = actor.guardian

          category_id = target_category_id(config["category_id"])
          old_category_id = topic.category_id

          guardian.ensure_can_edit!(topic)
          guardian.ensure_can_move_topic_to_category!(category_id)

          if topic.private_message?
            raise_node_error!(I18n.t("discourse_workflows.errors.topic_category.private_message"))
          end

          if category_id == SiteSetting.uncategorized_category_id &&
               !SiteSetting.allow_uncategorized_topics
            raise_node_error!(
              I18n.t("discourse_workflows.errors.topic_category.uncategorized_not_allowed"),
            )
          end

          if !topic.change_category_to_id(category_id) || topic.errors.present?
            errors = topic.errors.full_messages.presence
            raise_node_error!(
              errors&.join(", ") ||
                I18n.t("discourse_workflows.errors.topic_category.operation_failed"),
            )
          end

          { topic_id: topic.id, category_id: topic.category_id, old_category_id: old_category_id }
        end

        def target_category_id(raw_value)
          category_id = raw_value.presence.to_i
          return SiteSetting.uncategorized_category_id if category_id.zero?

          ::Category.find(category_id).id
        end
      end
    end
  end
end
