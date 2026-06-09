# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module AssignTopic
        class V1 < DiscourseWorkflows::NodeType
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
            capabilities: {
              run_scope: "per_item",
            },
            properties: {
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
                config = {
                  "operation" =>
                    exec_ctx.get_node_parameter("operation", item_index, default: "assign"),
                  "topic_id" => exec_ctx.get_node_parameter("topic_id", item_index),
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
            topic = ::Topic.find(config["topic_id"])
            assigner = ::Assigner.new(topic, actor)
            previously_assigned = topic.assignment&.assigned_to

            case config["operation"]
            when "unassign"
              assigner.unassign

              { previously_assigned: assignee_data(previously_assigned, actor.guardian) }
            else
              assignee = find_assignee(config["assignee"])
              if config["replace_existing"] != false && topic.assignment
                assigner.unassign
                topic.association(:assignment).reset
              end

              result = assigner.assign(assignee)

              unless result[:success]
                raise_node_error!(
                  I18n.t(
                    "discourse_assign.discourse_workflows.assign_topic.error",
                    reason: result[:reason],
                  ),
                )
              end

              {
                assignee: assignee_data(assignee, actor.guardian),
                previously_assigned: assignee_data(previously_assigned, actor.guardian),
              }
            end
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
