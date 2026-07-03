# frozen_string_literal: true

module DiscourseWorkflows
  class Modal::Respond
    include Service::Base

    NODE_TYPE = DiscourseWorkflows::Nodes::Modal::V1.identifier

    params do
      attribute :action_id, :string

      validates :action_id, presence: true
    end

    model :resume_request
    step :resume

    private

    def fetch_resume_request(params:)
      payload = DiscourseWorkflows::InteractiveResume.action_payload(params.action_id)
      return if payload.blank?

      execution =
        DiscourseWorkflows::Execution.find_by(id: payload["execution_id"], status: :waiting)
      return if execution.blank?

      waiting_node = execution.find_waiting_node
      return unless waiting_node && waiting_node["type"] == NODE_TYPE

      DiscourseWorkflows::InteractiveResume.from_action_id(
        params.action_id,
        expected_node_type: NODE_TYPE,
        allowed_actions:
          DiscourseWorkflows::Nodes::Modal::V1.button_values(waiting_node["parameters"]),
      )
    end

    def resume(resume_request:, guardian:)
      claimed = resume_request.claim
      fail!(I18n.t("discourse_workflows.errors.already_resumed")) if claimed.blank?

      claimed.resume!(
        DiscourseWorkflows::Nodes::Modal::V1.response_items(action: resume_request.action),
        user: guardian.user,
      )
    end
  end
end
