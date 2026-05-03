# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Execute
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :trigger_node_id, :string
      attribute :trigger_data, default: -> { {} }
      attribute :execution_mode, :string, default: "normal"
      attribute :error_depth, :integer, default: 0
      attribute :user_id, :integer
      attribute :workflow_execution_chain, default: -> { [] }

      validates :trigger_node_id, presence: true
    end

    policy :can_execute, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    model :workflow
    model :trigger_node
    model :user, optional: true
    model :execution, :run_workflow

    private

    def fetch_workflow(params:)
      if params.workflow_id.present?
        DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
      else
        DiscourseWorkflows::Workflow.enabled.find_each do |w|
          node = w.find_node(params.trigger_node_id)
          return w if node
        end
        nil
      end
    end

    def fetch_trigger_node(workflow:, params:)
      workflow.find_node(params.trigger_node_id)
    end

    def fetch_user(params:)
      User.find_by(id: params.user_id) if params.user_id.present?
    end

    def run_workflow(trigger_node:, workflow:, params:, user:)
      options =
        DiscourseWorkflows::Executor::ExecutionOptions.new(
          user: user,
          execution_mode: params.execution_mode.to_sym,
          error_depth: params.error_depth,
          workflow_execution_chain: Array.wrap(params.workflow_execution_chain),
        )
      executor =
        DiscourseWorkflows::Executor.new(workflow, trigger_node["id"], params.trigger_data, options)
      executor.run
      executor.execution
    end
  end
end
