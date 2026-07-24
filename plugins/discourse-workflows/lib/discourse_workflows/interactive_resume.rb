# frozen_string_literal: true

module DiscourseWorkflows
  class InteractiveResume
    class Request
      attr_reader :action, :target_user_id

      def initialize(execution:, action:, target_user_id: nil)
        @execution = execution
        @action = action
        @target_user_id = target_user_id
      end

      def claim
        claimed_execution =
          DiscourseWorkflows::Execution.claim_for_resume(
            @execution,
            resume_token: @execution.resume_token,
          )
        return if claimed_execution.blank?

        ClaimedRequest.new(execution: claimed_execution, action: action)
      end
    end

    class ClaimedRequest
      attr_reader :action

      def initialize(execution:, action:)
        @execution = execution
        @action = action
      end

      def resume!(response_items, user: nil)
        DiscourseWorkflows::WaitingExecution.resume_claimed(@execution, response_items, user: user)
      end
    end

    def self.action_id(execution_id:, resume_token:, action:, target_user_id: nil)
      DiscourseWorkflows::WaitingExecution.action_token(
        execution_id: execution_id,
        resume_token: resume_token,
        action: action,
        target_user_id: target_user_id,
      )
    end

    def self.action_payload(action_id)
      DiscourseWorkflows::WaitingExecution.action_token_payload(action_id)
    end

    def self.action_id?(action_id, expected_node_type:, allowed_actions:)
      from_action_id(
        action_id,
        expected_node_type: expected_node_type,
        allowed_actions: allowed_actions,
      ).present?
    end

    def self.from_action_id(action_id, expected_node_type:, allowed_actions:)
      payload = action_payload(action_id)
      return if payload.blank?
      return if allowed_actions.exclude?(payload["action"])

      execution =
        DiscourseWorkflows::WaitingExecution.find_by_action_token(
          action_id,
          expected_node_type: expected_node_type,
        )
      return if execution.blank?

      Request.new(
        execution: execution,
        action: payload["action"],
        target_user_id: payload["target_user_id"],
      )
    end
  end
end
