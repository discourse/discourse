# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module Assigned
        class V1 < DiscourseWorkflows::NodeType
          description(
            name: "trigger:assigned",
            version: "1.0",
            defaults: {
              icon: "user-plus",
              color: "cyan",
            },
            group: "discourse_triggers",
            events: [:assigned],
            available: -> { SiteSetting.assign_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_assign",
            output_contracts: [
              { schema: DiscourseAssign::Workflows::Schema::ASSIGNED_OUTPUT_SCHEMA },
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

          def initialize(assignment, *)
            super(parameters: {})
            @assignment = assignment
          end

          def valid?
            @assignment.present? && @assignment.topic.present? &&
              @assignment.assigned_to.present? && post.present?
          end

          def output
            {
              assignment: assignment_data,
              post: serialize_post(post),
              topic: serialize_record(@assignment.topic, TopicListItemSerializer),
            }
          end

          def matches?(trigger_ctx)
            !trigger_ctx.get_node_parameter("topic_assignments_only", false) || topic_assignment?
          end

          private

          def assignment_data
            {
              id: @assignment.id,
              target_type: @assignment.target_type,
              target_id: @assignment.target_id,
              topic_id: @assignment.topic_id,
              topic_assignment: topic_assignment?,
              assigned_to_id: @assignment.assigned_to_id,
              assigned_to_type: @assignment.assigned_to_type,
              assigned_to: assignee_data(@assignment.assigned_to),
              assigned_by_user: serialize_record(@assignment.assigned_by_user, BasicUserSerializer),
              note: @assignment.note,
              status: @assignment.status,
            }
          end

          def assignee_data(assignee)
            case assignee
            when ::User
              { type: "user", user: serialize_record(assignee, BasicUserSerializer), group: {} }
            when ::Group
              { type: "group", user: {}, group: serialize_record(assignee, BasicGroupSerializer) }
            else
              { type: nil, user: {}, group: {} }
            end
          end

          def post
            @post ||= @assignment.post
          end

          def topic_assignment?
            @assignment.target_type == "Topic"
          end
        end
      end
    end
  end
end
