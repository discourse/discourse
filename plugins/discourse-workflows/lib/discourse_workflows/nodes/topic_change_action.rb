# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Per-item actions on a topic, outputting the topic and whether it changed. Including modules or nodes
    # define a private `change(exec_ctx, topic, actor, item_index)` returning the item.
    module TopicChangeAction
      def self.description(name:, icon:, color:, i18n_scope:, changed:, properties: {}, output: {})
        {
          name:,
          version: "1.0",
          defaults: {
            icon:,
            color:,
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          i18n_scope:,
          output_contracts: [
            {
              schema:
                Schema.merge(
                  Schema::TOPIC_LIST_ITEM_SCHEMA,
                  Schema.document(
                    "changed" => {
                      "type" => "boolean",
                      "description" => changed,
                    },
                    **output,
                  ),
                ),
            },
          ],
          properties: {
            topic_id: {
              type: :string,
              required: true,
            },
            **properties,
            **NodeType.actor_property,
          },
        }
      end

      def execute(exec_ctx)
        items =
          exec_ctx.input_items.map.with_index do |_item, item_index|
            topic = ::Topic.find(exec_ctx.get_node_parameter("topic_id", item_index))
            actor = exec_ctx.actor_from_parameter("actor_username", item_index)
            wrap(change(exec_ctx, topic, actor, item_index))
          end

        [items]
      end
    end
  end
end
