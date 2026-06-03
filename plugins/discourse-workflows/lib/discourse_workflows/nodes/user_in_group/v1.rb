# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UserInGroup
      class V1 < NodeType
        description(
          name: "condition:user_in_group",
          version: "1.0",
          defaults: {
            icon: "user-group",
            color: "violet",
          },
          outputs: [
            { key: "true", label_key: "discourse_workflows.executions.statuses.kept" },
            { key: "false", label_key: "discourse_workflows.executions.statuses.rejected" },
          ],
          capabilities: {
            run_scope: "per_item",
          },
          properties: {
            username: {
              type: :string,
              required: true,
              ui: {
                control: :user,
              },
            },
            group_id: {
              type: :integer,
              required: true,
              type_options: {
                load_options_method: "groups",
              },
              ui: {
                control: :group_select,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.user_in_group.group_id_placeholder",
              },
            },
            actor_username: {
              type: :string,
              required: false,
              default: "system",
              ui: {
                control: :user,
              },
            },
          },
        )

        def self.load_options_context(context)
          case context.method_name
          when "groups"
            ::Group
              .order(:name)
              .pluck(:id, :name)
              .select { |_, name| context.matches_filter?(name) }
              .map { |id, name| { id:, name: } }
          end
        end

        def execute(exec_ctx)
          exec_ctx
            .input_items
            .each_with_index
            .partition { |_item, item_index| user_in_group?(exec_ctx, item_index) }
            .map { |items| items.map(&:first) }
        end

        private

        def user_in_group?(exec_ctx, item_index)
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          group = ::Group.find(exec_ctx.get_node_parameter("group_id", item_index))
          actor.guardian.ensure_can_see_group!(group)

          user = exec_ctx.find_user(username: exec_ctx.get_node_parameter("username", item_index))
          ::GroupUser.exists?(group_id: group.id, user_id: user.id)
        end
      end
    end
  end
end
