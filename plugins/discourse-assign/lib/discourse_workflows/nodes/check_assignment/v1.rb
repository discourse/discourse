# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module CheckAssignment
        class V1 < DiscourseWorkflows::NodeType
          TARGET_TYPES = %w[topic post].freeze

          description(
            name: "action:check_assignment",
            version: "1.0",
            defaults: {
              icon: "user-check",
              color: "cyan",
            },
            group: "discourse_actions",
            available: -> { SiteSetting.assign_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_assign",
            capabilities: {
              run_scope: "per_item",
            },
            output_contracts: [
              {
                schema: DiscourseAssign::Workflows::Schema::CHECK_ASSIGNMENT_OUTPUT_SCHEMA,
                mode: :merge,
              },
            ],
            properties: {
              target_type: {
                type: :options,
                required: true,
                options: TARGET_TYPES,
                default: "topic",
                no_data_expression: true,
              },
              topic_id: {
                type: :string,
                required: true,
                display_options: {
                  show: {
                    target_type: ["topic"],
                  },
                },
              },
              post_id: {
                type: :string,
                required: true,
                display_options: {
                  show: {
                    target_type: ["post"],
                  },
                },
              },
              assignee: {
                type: :string,
                required: true,
                ui: {
                  control: :user_or_group,
                },
              },
            },
          )

          def execute(exec_ctx)
            items =
              exec_ctx.input_items.map.with_index do |item, item_index|
                target_type =
                  exec_ctx.get_node_parameter("target_type", item_index, default: "topic").to_s
                target = find_target(exec_ctx, target_type, item_index)
                assignee = find_assignee(exec_ctx.get_node_parameter("assignee", item_index))
                is_assigned = ::Assignment.active.exists?(target:, assigned_to: assignee)

                wrap(
                  item.fetch("json", {}).merge("is_assigned" => is_assigned),
                  paired_item: exec_ctx.paired_item_for(item),
                )
              end

            [items]
          end

          private

          def find_target(exec_ctx, target_type, item_index)
            case target_type
            when "topic"
              ::Topic.find(exec_ctx.get_node_parameter("topic_id", item_index))
            when "post"
              ::Post.find(exec_ctx.get_node_parameter("post_id", item_index))
            else
              raise_node_error!(
                I18n.t(
                  "discourse_assign.discourse_workflows.check_assignment.unknown_target_type",
                  target_type:,
                ),
              )
            end
          end

          def find_assignee(identifier)
            ::User.find_by(username: identifier) || ::Group.find_by!(name: identifier)
          end
        end
      end
    end
  end
end
