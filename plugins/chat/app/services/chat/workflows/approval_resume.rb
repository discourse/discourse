# frozen_string_literal: true

module Chat
  module Workflows
    class ApprovalResume
      include Service::Base

      policy :workflows_enabled

      params do
        attribute :execution_id, :integer
        attribute :approved, :boolean
        attribute :action_token, :string
        attribute :channel_id, :integer

        validates :execution_id, presence: true
        validates :action_token, presence: true
      end

      model :execution
      step :resume_execution

      private

      def workflows_enabled
        SiteSetting.discourse_workflows_enabled
      end

      def fetch_execution(params:)
        resume_token, action_type = params.action_token.to_s.split(":", 2)
        return nil if %w[approve deny].exclude?(action_type)
        return nil if resume_token.blank?

        found =
          ::DiscourseWorkflows::Execution.by_resume_token(resume_token).find_by(
            id: params.execution_id,
          )
        return nil unless found

        ::DiscourseWorkflows::Execution.claim_for_resume(id: found.id, resume_token: resume_token)
      end

      def resume_execution(execution:, params:)
        response_items = [
          { "json" => { "approved" => params.approved, "channel_id" => params.channel_id } },
        ]
        ::DiscourseWorkflows::Executor.resume(execution, response_items)
      end
    end
  end
end
