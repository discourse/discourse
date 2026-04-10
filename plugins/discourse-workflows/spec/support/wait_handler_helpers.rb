# frozen_string_literal: true

module WaitHandlerHelpers
  def build_wait_state(execution, node_type:, configuration: {}, context: {})
    state =
      instance_double(
        DiscourseWorkflows::Executor::ExecutionState,
        execution: execution,
        waiting_step:
          DiscourseWorkflows::Executor::Step.new(
            node_id: "wait-1",
            node_name: "Wait",
            node_type: node_type,
            position: 0,
            input: [],
          ),
        waiting_node:
          DiscourseWorkflows::WorkflowSnapshot::SnapshotNode.new(
            id: "wait-1",
            type: node_type,
            type_version: "1.0",
            name: "Wait",
            position: {
              "x" => 0,
              "y" => 0,
            },
            configuration: configuration,
          ),
        waiting_config: {
        },
        context: context,
      )
    allow(state).to receive(:save!)
    state
  end
end

RSpec.configure { |config| config.include WaitHandlerHelpers }
