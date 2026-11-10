# frozen_string_literal: true

module DiscourseAssign
  module Workflows
    module AssignmentTrigger
      def initialize(assignment, payload = {})
        super(parameters: {})
        @assignment = assignment
        @actor = payload[:acting_user]
      end

      def valid?
        @assignment.present? && @assignment.topic.present? && @assignment.assigned_to.present? &&
          post.present?
      end

      def matches?(trigger_ctx)
        !trigger_ctx.get_node_parameter("topic_assignments_only", false) || topic_assignment?
      end

      def output
        {
          assignment: serialize_assignment,
          post: serialize_post(post),
          topic: serialize_topic_list_item(@assignment.topic),
          actor: serialize_user(@actor),
        }
      end

      private

      def serialize_assignment
        {
          id: @assignment.id,
          target_type: @assignment.target_type,
          target_id: @assignment.target_id,
          topic_id: @assignment.topic_id,
          topic_assignment: topic_assignment?,
          assigned_to_id: @assignment.assigned_to_id,
          assigned_to_type: @assignment.assigned_to_type,
          assigned_to: serialize_assignee(@assignment.assigned_to),
          assigned_by_user: serialize_user(@assignment.assigned_by_user),
          note: @assignment.note,
          status: @assignment.status,
        }
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
