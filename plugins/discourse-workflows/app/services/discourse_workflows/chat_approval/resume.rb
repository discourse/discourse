# frozen_string_literal: true

module DiscourseWorkflows
  module ChatApproval
    class Resume
      include Service::Base

      policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled

      params do
        attribute :execution_id, :integer
        attribute :approved, :boolean
        attribute :wait_nonce, :string

        validates :execution_id, presence: true
        validates :wait_nonce, presence: true
      end

      model :execution
      step :resume_execution

      private

      def fetch_execution(params:)
        DiscourseWorkflows::Execution
          .waiting_with_type("chat_approval")
          .where(id: params.execution_id)
          .where("waiting_config->>'wait_nonce' = ?", params.wait_nonce)
          .lock("FOR UPDATE SKIP LOCKED")
          .first
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
        DiscourseWorkflows::Executor.resume(execution, response_items)
      end
    end
  end
end
