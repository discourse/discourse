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
        execution =
          ::DiscourseWorkflows::Execution
            .waiting_with_type("chat_approval")
            .where(id: params.execution_id)
            .lock("FOR UPDATE SKIP LOCKED")
            .first

        return nil unless execution

        approve_token = execution.waiting_config&.dig("approve_token").to_s
        deny_token = execution.waiting_config&.dig("deny_token").to_s
        token = params.action_token.to_s

        unless ActiveSupport::SecurityUtils.secure_compare(approve_token, token) ||
                 ActiveSupport::SecurityUtils.secure_compare(deny_token, token)
          return nil
        end

        execution
      end

      def resume_execution(execution:, params:)
        response_items = [
          {
            "json" => {
              "approved" => params.approved,
              "channel_id" => execution.waiting_config&.dig("chat_channel_id"),
            },
          },
        ]
        ::DiscourseWorkflows::Executor.resume(execution, response_items)
      end
    end
  end
end
