# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module AssignTopic
        class V2 < V1
          include AssignmentAction

          description(
            superclass.description.merge(
              version: "2.0",
              output_contracts: [
                {
                  schema:
                    DiscourseWorkflows::Schema.merge(
                      DiscourseAssign::Workflows::Schema::ASSIGN_TOPIC_V2_OUTPUT_SCHEMA,
                      DiscourseWorkflows::Schema::ACTOR_SCHEMA,
                    ),
                },
              ],
              properties: {
                **AssignmentAction.target_properties,
                assignee: {
                  type: :string,
                  required: true,
                  ui: {
                    control: :user_or_group,
                  },
                },
                replace_existing: {
                  type: :boolean,
                  default: true,
                },
                **DiscourseWorkflows::NodeType.actor_property(allow_anonymous: false),
              },
            ),
          )

          private

          def change_assignment(exec_ctx, target, actor, item_index)
            assignee = find_assignee(exec_ctx.get_node_parameter("assignee", item_index))
            replace_existing =
              exec_ctx.get_node_parameter("replace_existing", item_index, default: true)
            previously_assigned = target.assignment&.assigned_to
            changed = previously_assigned != assignee

            if changed
              assigner = ::Assigner.new(target, actor)
              if replace_existing != false && target.assignment
                assigner.unassign
                target.association(:assignment).reset
              end

              result = assigner.assign(assignee)
              if !result[:success]
                raise_node_error!(
                  I18n.t(
                    "discourse_assign.discourse_workflows.assign_topic.error",
                    reason: Assigner.failure_message(result[:reason], assignee),
                  ),
                  item_index:,
                )
              end
            end

            {
              assignee: serialize_assignee(assignee, guardian: actor.guardian),
              previously_assigned:
                serialize_assignee(previously_assigned, guardian: actor.guardian),
              actor: serialize_user(actor),
              changed:,
            }
          end
        end
      end
    end
  end
end
