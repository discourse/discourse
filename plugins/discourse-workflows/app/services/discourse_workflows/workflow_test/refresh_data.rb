# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTest::RefreshData
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
    policy :test_has_checks
    transaction { model :workflow_test, :discard_captured_lookups }
    model :execution, :enqueue_run

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_workflow_test(workflow:, params:)
      workflow.workflow_tests.find_by(id: params.test_id)
    end

    def test_has_checks(workflow_test:)
      workflow_test.checks.any?
    end

    def discard_captured_lookups(workflow_test:, guardian:)
      recorded_keys =
        workflow_test
          .replay_steps
          .select { |step| step["kind"] == "external" }
          .map { |step| step["name"] }
      kept =
        workflow_test.captured_outputs.select do |key, _entries|
          recorded_keys.include?(key.rpartition(":").first)
        end
      workflow_test.update(captured_outputs: kept, captured_at: nil, updated_by: guardian.user)
      workflow_test
    end

    def enqueue_run(workflow_test:, guardian:)
      WorkflowTest::Action::EnqueueRun.call(workflow_test:, user: guardian.user)
    end
  end
end
