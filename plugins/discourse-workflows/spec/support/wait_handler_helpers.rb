# frozen_string_literal: true

module WaitHandlerHelpers
  def build_wait_dependencies(execution, node_type:, configuration: {}, context: {})
    waiting_step =
      DiscourseWorkflows::Executor::Step.new(
        node_id: "wait-1",
        node_name: "Wait",
        node_type: node_type,
        position: 0,
        input: [],
      )
    waiting_node =
      DiscourseWorkflows::WorkflowSnapshot::SnapshotNode.new(
        id: "wait-1",
        type: node_type,
        typeVersion: "1.0",
        name: "Wait",
        position: {
          "x" => 0,
          "y" => 0,
        },
        configuration: configuration,
      )
    persistence =
      instance_double(DiscourseWorkflows::Executor::ExecutionStore, execution: execution)
    allow(persistence).to receive(
      :pause_waiting_execution!,
    ) do |node:, waiting_until: nil, steps: []|
      execution.update!(
        status: :waiting,
        waiting_node_id: node.id,
        waiting_until: waiting_until,
        resume_token: context["__resume_token"],
      )
      execution
    end

    {
      persistence: persistence,
      context:
        instance_double(
          DiscourseWorkflows::Executor::ExecutionContext,
          resume_token: context["__resume_token"],
        ),
      node: waiting_node,
      step: waiting_step,
      steps: [],
    }
  end
end

RSpec.configure { |config| config.include WaitHandlerHelpers }
