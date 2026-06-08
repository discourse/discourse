# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Group
      class V1 < NodeType
        OPERATIONS = %w[add remove get].freeze

        description(
          name: "action:group",
          version: "1.0",
          defaults: {
            icon: "user-plus",
            color: "indigo",
          },
          group: "discourse_actions",
          capabilities: {
            run_scope: "per_item",
          },
          properties: {
            operation: {
              type: :options,
              required: true,
              options: OPERATIONS,
              default: "add",
              ui: {
                expression: true,
              },
            },
            username: {
              type: :string,
              required: true,
              display_options: {
                show: {
                  operation: %w[add remove],
                },
              },
              ui: {
                control: :user,
              },
            },
            group_id: {
              type: :integer,
              required: true,
              type_options: {
                load_options_method: "groups",
                load_options_depends_on: %w[operation],
              },
              ui: {
                control: :group_select,
              },
              control_options: {
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.group.group_id_placeholder",
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
            scope = ::Group.order(:name)
            scope = scope.where(automatic: false) unless context.get_current_node_parameter(
              "operation",
            ) == "get"

            scope
              .pluck(:id, :name)
              .select { |_, name| context.matches_filter?(name) }
              .map { |id, name| { id:, name: } }
          end
        end

        def execute(exec_ctx)
          items =
            exec_ctx.input_items.map.with_index do |_item, item_index|
              config = {
                "operation" => exec_ctx.get_node_parameter("operation", item_index, default: "add"),
                "username" => exec_ctx.get_node_parameter("username", item_index),
                "group_id" => exec_ctx.get_node_parameter("group_id", item_index),
              }

              wrap(process(exec_ctx, config, item_index))
            end

          [items]
        end

        private

        def process(exec_ctx, config, item_index)
          group = ::Group.find(config["group_id"])
          actor = exec_ctx.actor_from_parameter("actor_username", item_index)
          guardian = actor.guardian
          guardian.ensure_can_see_group!(group)
          serialized_group = group_data(group, guardian)

          return { group: serialized_group } if config["operation"] == "get"

          guardian.ensure_can_edit_group!(group)

          user = exec_ctx.find_user(username: config["username"])

          logger = GroupActionLogger.new(actor, group)

          case config["operation"]
          when "remove"
            group.remove(user)
            logger.log_remove_user_from_group(user)
          else
            group.add(user)
            logger.log_add_user_to_group(user)
          end

          { group: serialized_group, user: user_data(user, guardian) }
        end

        def group_data(group, guardian)
          serialize_record(group, WebHookGroupSerializer, scope: guardian)
        end

        def user_data(user, guardian)
          serialize_record(user, BasicUserSerializer, scope: guardian)
        end
      end
    end
  end
end
