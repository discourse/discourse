# frozen_string_literal: true

module DiscourseWorkflows
  module AiAuthoring
    class Apply
      include Service::Base

      policy :ai_authoring_enabled

      params do
        attribute :session_id, :integer
        attribute :workflow_id, :integer

        validates :session_id, :workflow_id, presence: true
      end

      policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
      model :session
      model :workflow
      policy :proposal_ready
      model :operations, :extract_operations
      policy :proposal_current
      model :patch_result, :apply_patch
      policy :patch_valid
      step :mark_proposal_applied

      private

      def ai_authoring_enabled
        DiscourseWorkflows::AiAuthoringEnqueuer.enabled?
      end

      def fetch_session(params:, guardian:)
        DiscourseWorkflows::AiAuthoringSession.find_by(
          id: params.session_id,
          user_id: guardian.user.id,
          workflow_id: params.workflow_id,
        )
      end

      def fetch_workflow(session:)
        session.workflow
      end

      def proposal_ready(session:)
        session.status == "proposal_ready"
      end

      def extract_operations(session:)
        proposal = session.proposed_patch || {}
        proposal["operations"] || proposal[:operations]
      end

      def proposal_current(session:, workflow:)
        session.base_graph_digest.blank? ||
          DiscourseWorkflows::Ai::GraphDigest.call(workflow) == session.base_graph_digest
      end

      def apply_patch(workflow:, operations:, guardian:)
        DiscourseWorkflows::Workflow::Action::ApplyPatch.call(
          workflow: workflow,
          operations: operations,
          persist: true,
          user: guardian.user,
        )
      end

      def patch_valid(patch_result:)
        patch_result[:valid]
      end

      def mark_proposal_applied(session:)
        session.update!(status: "applied", applied_at: Time.current)
      end
    end
  end
end
