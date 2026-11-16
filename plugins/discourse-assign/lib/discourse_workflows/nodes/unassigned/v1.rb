# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module Unassigned
        class V1 < DiscourseWorkflows::NodeType
          include DiscourseAssign::Workflows::AssignmentTrigger

          description(
            name: "trigger:unassigned",
            version: "1.0",
            defaults: {
              icon: "user-xmark",
              color: "cyan",
            },
            group: "discourse_triggers",
            event: :unassigned,
            available: -> { SiteSetting.assign_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_assign",
            output_contracts: [
              { schema: DiscourseAssign::Workflows::Schema::ASSIGNMENT_OUTPUT_SCHEMA },
            ],
            properties: {
              topic_assignments_only: {
                type: :boolean,
                default: false,
                ui: {
                  control: :checkbox,
                },
              },
            },
          )

          deprecated(
            superseded_by: "2.0",
            changes: {
              "assignment.assigned_by_user" => "assignment.assigned_by",
            },
          )
        end
      end
    end
  end
end
