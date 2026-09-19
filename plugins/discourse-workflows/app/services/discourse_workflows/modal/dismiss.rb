# frozen_string_literal: true

module DiscourseWorkflows
  class Modal::Dismiss
    include Service::Base

    params do
      attribute :modal_id, :string

      validates :modal_id,
                presence: true,
                length: {
                  maximum: DiscourseWorkflows::Nodes::Modal::V1::MODAL_ID_MAX_LENGTH,
                }
    end

    step :close_modal_in_all_tabs

    private

    def close_modal_in_all_tabs(params:, guardian:)
      DiscourseWorkflows::Nodes::Modal::V1.publish_close(guardian.user.id, params.modal_id)
    end
  end
end
