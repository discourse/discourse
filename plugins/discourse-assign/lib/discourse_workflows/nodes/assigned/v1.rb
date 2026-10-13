# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module Assigned
        class V1 < DiscourseWorkflows::NodeType
          include DiscourseAssign::Workflows::AssignmentTrigger

          description(
            name: "trigger:assigned",
            version: "1.0",
            defaults: {
              icon: "user-plus",
              color: "cyan",
            },
            group: "discourse_triggers",
            event: :assigned,
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
        end
      end
    end
  end
end
