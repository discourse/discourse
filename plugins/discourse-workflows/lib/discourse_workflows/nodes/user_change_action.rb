# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Per-item actions on a user, outputting the user, the actor and whether the user changed. Including
    # modules define a private `change_user(exec_ctx, item_index)` returning the item, usually #user_output.
    module UserChangeAction
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
                  Schema::USER_SCHEMA,
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
            username: {
              type: :string,
              required: true,
              ui: {
                control: :user,
              },
            },
            **properties,
            **NodeType.actor_property(allow_anonymous: false),
          },
        }
      end

      def execute(exec_ctx)
        items =
          exec_ctx.input_items.map.with_index do |_item, item_index|
            wrap(change_user(exec_ctx, item_index))
          end

        [items]
      end

      private

      def find_actor_and_user(exec_ctx, item_index)
        actor = exec_ctx.actor_from_parameter("actor_username", item_index)
        username = exec_ctx.get_node_parameter("username", item_index).to_s.presence
        if username.nil?
          raise_node_error!(
            I18n.t("discourse_workflows.errors.actor.blank", field: "username"),
            item_index:,
          )
        end

        [actor, exec_ctx.find_user(username:, item_index:)]
      end

      def user_output(user, actor, changed:, **extra)
        { user: serialize_user(user), actor: serialize_user(actor), changed:, **extra }
      end
    end
  end
end
