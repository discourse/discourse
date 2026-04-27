# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Show
    include Service::Base

    params do
      attribute :workflow_id, :integer
      validates :workflow_id, presence: true
    end

    model :workflow
    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.includes(:created_by, :updated_by, :error_workflow).find_by(
        id: params.workflow_id,
      )
    end
  end
end
