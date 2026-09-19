# frozen_string_literal: true

module DiscourseWorkflows
  class Modal::Respond
    include Service::Base

    NODE_TYPE = DiscourseWorkflows::Nodes::Modal::V1.identifier

    params do
      attribute :action_id, :string
      attribute :modal_id, :string

      validates :action_id, presence: true
      validates :modal_id,
                length: {
                  maximum: DiscourseWorkflows::Nodes::Modal::V1::MODAL_ID_MAX_LENGTH,
                }
    end

    model :payload
    policy :targets_current_user
    # The token is bound to the resume token consumed on resume, so a click on
    # a leftover copy of an already-handled modal matches nothing — treat that
    # as success (clean up the copies) rather than a misleading 404.
    model :resume_request, optional: true
    only_if(:resume_request_present?) { step :resume }
    # After the resume, so an error raised while resuming leaves the other
    # tabs' copies open — they are the only remaining way to answer.
    only_if(:modal_id_present?) { step :close_modal_in_all_tabs }

    private

    def fetch_payload(params:)
      DiscourseWorkflows::InteractiveResume.action_payload(params.action_id)
    end

    def targets_current_user(payload:, guardian:)
      payload["target_user_id"].present? && payload["target_user_id"] == guardian.user&.id
    end

    def fetch_resume_request(params:, payload:)
      # Node checks inlined: find_waiting_node re-parses the snapshot per call.
      execution =
        DiscourseWorkflows::WaitingExecution.find_by_action_token(
          params.action_id,
          expected_node_type: nil,
        )
      return if execution.blank?

      waiting_node = execution.find_waiting_node
      return unless waiting_node && waiting_node["type"] == NODE_TYPE

      action = payload["action"]
      allowed_actions =
        DiscourseWorkflows::Nodes::Modal::V1.button_values(waiting_node["parameters"])
      return if allowed_actions.exclude?(action)

      DiscourseWorkflows::InteractiveResume::Request.new(
        execution:,
        action:,
        target_user_id: payload["target_user_id"],
      )
    end

    def resume_request_present?(resume_request:)
      resume_request.present?
    end

    def modal_id_present?(params:)
      params.modal_id.present?
    end

    def close_modal_in_all_tabs(params:, guardian:)
      DiscourseWorkflows::Nodes::Modal::V1.publish_close(guardian.user.id, params.modal_id)
    end

    def resume(resume_request:, guardian:)
      claimed = resume_request.claim
      # Another tab or device answered first; the modal was handled either way.
      return if claimed.blank?

      claimed.resume!(
        DiscourseWorkflows::Nodes::Modal::V1.response_items(action: resume_request.action),
        user: guardian.user,
      )
    end
  end
end
