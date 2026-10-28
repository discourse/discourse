# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTest::List
    include Service::Base

    params do
      attribute :workflow_id, :integer

      validates :workflow_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    policy :workflow_tests_enabled, class_name: Policy::WorkflowTestsEnabled
    model :workflow
    model :workflow_tests, optional: true

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_workflow_tests(workflow:)
      workflow
        .workflow_tests
        .includes(latest_execution: :execution_data)
        .order(:created_at, :id)
        .to_a
    end
  end
end
