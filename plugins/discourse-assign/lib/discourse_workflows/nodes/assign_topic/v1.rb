# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module AssignTopic
        class V1 < DiscourseWorkflows::NodeType
          RESOURCES = %w[topic post].freeze
          OPERATIONS = %w[assign unassign].freeze

          description(
            name: "action:assign_topic",
            version: "1.0",
            defaults: {
              icon: "user-plus",
              color: "cyan",
            },
            available: -> { SiteSetting.assign_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_assign",
            output_contracts: [
              { schema: DiscourseAssign::Workflows::Schema::ASSIGN_TOPIC_OUTPUT_SCHEMA },
            ],
            capabilities: {
              run_scope: "per_item",
            },
            properties: {
              resource: {
                type: :options,
                required: true,
                options: RESOURCES,
                default: "topic",
                no_data_expression: true,
              },
              operation: {
                type: :options,
                required: true,
                options: OPERATIONS,
                default: "assign",
                ui: {
                  expression: true,
                },
              },
              topic_id: {
                type: :string,
                required: true,
                display_options: {
                  show: {
                    resource: ["topic"],
                  },
                },
              },
              post_id: {
                type: :string,
                required: true,
                display_options: {
                  show: {
                    resource: ["post"],
                  },
                },
              },
              assignee: {
                type: :string,
                required: true,
                display_options: {
                  show: {
                    operation: ["assign"],
                  },
                },
                ui: {
                  control: :user_or_group,
                },
              },
              replace_existing: {
                type: :boolean,
                default: true,
                display_options: {
                  show: {
                    operation: ["assign"],
                  },
                },
              },
            },
          )

          def execute(exec_ctx)
            actor = exec_ctx.user || Discourse.system_user
            items =
              exec_ctx.input_items.map.with_index do |_item, item_index|
                resource =
                  exec_ctx.get_node_parameter("resource", item_index, default: "topic").to_s
                config = {
                  "operation" =>
                    exec_ctx.get_node_parameter("operation", item_index, default: "assign"),
                  "resource" => resource,
                  "target_id" => exec_ctx.get_node_parameter("#{resource}_id", item_index),
                  "assignee" => exec_ctx.get_node_parameter("assignee", item_index),
                  "replace_existing" =>
                    exec_ctx.get_node_parameter("replace_existing", item_index, default: true),
                }
                result = process(actor, config)
                wrap(result)
              end
            [items]
          end

          private

          def process(actor, config)
            target = find_target(config["resource"], config["target_id"])
            assigner = ::Assigner.new(target, actor)
            previously_assigned = target.assignment&.assigned_to

            case config["operation"]
            when "unassign"
              assigner.unassign

              { previously_assigned: assignee_data(previously_assigned, actor.guardian) }
            else
              assignee = find_assignee(config["assignee"])
              if config["replace_existing"] != false && target.assignment
                assigner.unassign
                target.association(:assignment).reset
              end

              result = assigner.assign(assignee)

              unless result[:success]
                raise_node_error!(
                  I18n.t(
                    "discourse_assign.discourse_workflows.assign_topic.error",
                    reason: Assigner.failure_message(result[:reason], assignee),
                  ),
                )
              end

              {
                assignee: assignee_data(assignee, actor.guardian),
                previously_assigned: assignee_data(previously_assigned, actor.guardian),
              }
            end
          end

          def find_target(resource, target_id)
            resource == "post" ? ::Post.find(target_id) : ::Topic.find(target_id)
          end

          def find_assignee(identifier)
            ::User.find_by(username: identifier) || ::Group.find_by!(name: identifier)
          end

          def assignee_data(assignee, guardian)
            case assignee
            when ::User
              {
                type: "user",
                user: serialize_record(assignee, BasicUserSerializer, scope: guardian),
                group: {
                },
              }
            when ::Group
              {
                type: "group",
                user: {
                },
                group: serialize_record(assignee, BasicGroupSerializer, scope: guardian),
              }
            else
              { type: nil, user: {}, group: {} }
            end
          end
        end
      end
    end
  end
end
