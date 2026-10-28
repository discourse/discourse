# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTest::Run
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :test_ids, default: -> { [] }

      validates :workflow_id, presence: true

      def selected_test_ids
        Array.wrap(test_ids).map(&:to_i)
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    policy :workflow_tests_enabled, class_name: Policy::WorkflowTestsEnabled
    model :workflow
    model :workflow_tests
    policy :tests_have_checks
    model :executions, :enqueue_runs

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_workflow_tests(workflow:, params:)
      scope = workflow.workflow_tests.order(:created_at, :id)
      scope = scope.where(id: params.selected_test_ids) if params.selected_test_ids.any?
      tests = scope.to_a
      if tests.any? &&
           (params.selected_test_ids.empty? || tests.size == params.selected_test_ids.uniq.size)
        tests
      end
    end

    def tests_have_checks(workflow_tests:)
      workflow_tests.all? { |workflow_test| workflow_test.checks.any? }
    end

    def enqueue_runs(workflow_tests:, guardian:)
      workflow_tests.map do |workflow_test|
        WorkflowTest::Action::EnqueueRun.call(workflow_test:, user: guardian.user)
      end
    end
  end
end
