# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module UnassignTopic
        class V1 < DiscourseWorkflows::NodeType
          include AssignmentAction

          description(
            name: "action:unassign_topic",
            version: "1.0",
            defaults: {
              icon: "user-xmark",
              color: "cyan",
            },
            available: -> { SiteSetting.assign_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_assign",
            output_contracts: [
              {
                schema:
                  DiscourseWorkflows::Schema.merge(
                    DiscourseAssign::Workflows::Schema::UNASSIGN_TOPIC_OUTPUT_SCHEMA,
                    DiscourseWorkflows::Schema::ACTOR_SCHEMA,
                  ),
              },
            ],
            capabilities: {
              run_scope: "per_item",
            },
            properties: {
              **AssignmentAction.target_properties,
              **DiscourseWorkflows::NodeType.actor_property(allow_anonymous: false),
            },
          )

          private

          # Like the unassign button: whoever was assigned is notified, and a small action post is added.
          def change_assignment(_exec_ctx, target, actor, _item_index)
            assignment = target.assignment
            previously_assigned = assignment&.assigned_to

            {
              previously_assigned:
                serialize_assignee(previously_assigned, guardian: actor.guardian),
              actor: serialize_user(actor),
              changed: assignment.present? && unassign(target, assignment, actor),
            }
          end

          # The unassigner doesn't say whether it removed anything, so lock the assignment first: a concurrent
          # unassign that already removed it raises instead of being reported twice.
          def unassign(target, assignment, actor)
            ::Assignment.transaction do
              assignment.lock!
              ::Assigner.new(target, actor).unassign
              true
            end
          rescue ActiveRecord::RecordNotFound
            false
          end
        end
      end
    end
  end
end
