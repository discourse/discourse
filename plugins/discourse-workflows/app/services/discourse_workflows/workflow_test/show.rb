# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTest::Show
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :test_id, :integer

      validates :workflow_id, :test_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    policy :workflow_tests_enabled, class_name: Policy::WorkflowTestsEnabled
    model :workflow
    model :workflow_test

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_workflow_test(workflow:, params:)
      workflow
        .workflow_tests
        .includes(latest_execution: :execution_data)
        .find_by(id: params.test_id)
    end
  end
end
