# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Per-item actions on a post, outputting the post, the actor and whether the post changed. Including
    # modules define a private `change_post(exec_ctx, item_index)` returning the item, usually #post_output.
    module PostChangeAction
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
                  Schema::POST_SCHEMA,
                  Schema::ACTOR_SCHEMA,
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
            post_id: {
              type: :string,
              required: true,
            },
            **properties,
            **NodeType.actor_property(allow_anonymous: false),
          },
        }
      end

      def execute(exec_ctx)
        items =
          exec_ctx.input_items.map.with_index do |_item, item_index|
            wrap(change_post(exec_ctx, item_index))
          end

        [items]
      end

      private

      def post_output(post, actor, changed:)
        {
          post: serialize_post(post, guardian: actor.guardian),
          actor: serialize_user(actor),
          changed:,
        }
      end
    end
  end
end
