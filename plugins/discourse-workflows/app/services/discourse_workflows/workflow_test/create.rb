# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTest::Create
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :execution_id, :integer
      attribute :name, :string
      attribute :checks, default: -> { [] }

      validates :workflow_id, :execution_id, presence: true
      validates :name, length: { maximum: 100 }, allow_nil: true

      def normalized_checks
        WorkflowTestChecks.normalize(checks)
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    policy :workflow_tests_enabled, class_name: Policy::WorkflowTestsEnabled

    lock(:workflow_id) do
      model :workflow
      model :source_execution
      model :trigger_node
      policy :source_has_input
      policy :within_test_limit

      transaction { model :workflow_test, :create_workflow_test }
    end

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_source_execution(workflow:, params:)
      workflow.executions.includes(:execution_data).find_by(id: params.execution_id)
    end

    def fetch_trigger_node(source_execution:)
      source_execution.execution_data&.workflow_data.presence &&
        WorkflowSnapshot
          .new(source_execution.execution_data.workflow_data)
          .find_node(source_execution.trigger_node_id)
          &.to_workflow_node
    end

    def source_has_input(source_execution:, trigger_node:)
      return false if source_execution.rate_limited?

      source_execution.trigger_data.present? || trigger_node["type"] == "trigger:manual"
    end

    def within_test_limit(workflow:)
      workflow.workflow_tests.count < WorkflowTest::MAX_PER_WORKFLOW
    end

    def create_workflow_test(workflow:, source_execution:, trigger_node:, params:, guardian:)
      workflow.workflow_tests.create(
        name: params.name.presence || default_name(source_execution),
        trigger_node_id: trigger_node["id"],
        trigger_type: trigger_node["type"],
        trigger_type_version: trigger_node["typeVersion"] || 1,
        trigger_data: source_execution.trigger_data || {},
        source_execution_id: source_execution.id,
        captured_outputs: seeded_captures(source_execution, workflow),
        checks: initial_checks(source_execution, params),
        created_by: guardian.user,
        updated_by: guardian.user,
      )
    end

    def default_name(source_execution)
      I18n.t("discourse_workflows.tests.default_name", execution_id: source_execution.id)
    end

    def seeded_captures(source_execution, workflow)
      return {} if source_execution.simulation?

      WorkflowTestSourceCaptures.from_run_data(
        source_execution.execution_data&.run_data,
        nodes: workflow.nodes,
      )
    end

    def initial_checks(source_execution, params)
      checks = params.normalized_checks
      return checks if checks.any?

      suggested =
        if source_execution.simulation?
          WorkflowTestChecks.from_effects(
            source_execution.execution_data&.simulation&.dig("effects") || [],
          )
        else
          []
        end
      [WorkflowTestChecks.finishes, *suggested]
    end
  end
end
