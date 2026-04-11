# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::NodeRouter do
  subject(:router) do
    described_class.new(
      context: context,
      journal: journal,
      runtime: runtime,
      step_runner: step_runner,
      snapshot: snapshot,
      user: nil,
      run_as_user_proc: -> { nil },
    )
  end

  fab!(:workflow, :discourse_workflows_workflow)

  let(:context) do
    instance_double(
      DiscourseWorkflows::Executor::ExecutionContext,
      workflow: workflow,
      node_context_for: {
      },
    )
  end
  let(:journal) do
    instance_double(DiscourseWorkflows::Executor::StepsJournal, next_step_position: 1)
  end
  let(:runtime) do
    instance_double(DiscourseWorkflows::Executor::ExecutionRuntime, preloaded_vars: {})
  end
  let(:step_runner) { instance_double(DiscourseWorkflows::Executor::StepRunner) }
  let(:snapshot) do
    DiscourseWorkflows::WorkflowSnapshot.new(
      "nodes" => [
        { "id" => "source-1", "type" => "condition:test", "name" => "Source" },
        { "id" => "target-1", "type" => "action:test", "name" => "Target" },
      ],
      "connections" => [
        {
          "source_node_id" => "source-1",
          "source_output" => "false",
          "target_node_id" => "target-1",
        },
      ],
    )
  end
  let(:node) { snapshot.find_node("source-1") }
  let(:target_node) { snapshot.find_node("target-1") }
  let(:node_type_class) do
    Class.new(DiscourseWorkflows::NodeType) do
      def self.identifier
        "condition:test"
      end

      def self.ports
        [{ key: "true" }, { key: "false" }]
      end
    end
  end
  let(:step) do
    DiscourseWorkflows::Executor::Step.build(node: node, position: 1, input: [{ "json" => {} }])
  end

  describe "#execute_node" do
    it "routes normalized outputs by port name" do
      result = DiscourseWorkflows::NodeResult.new("false" => [{ "json" => { "id" => 2 } }])

      allow(DiscourseWorkflows::Registry).to receive(:find_node_type).and_return(node_type_class)
      allow(step_runner).to receive(:run).and_return(
        DiscourseWorkflows::Executor::StepOutcome.success(step: step, result: result),
      )

      commands = router.execute_node(node, [{ "json" => {} }])

      expect(commands).to include(
        DiscourseWorkflows::Executor::RoutingCommand::StoreContext.new(
          name: "Source",
          items: [{ "json" => { "id" => 2 } }],
        ),
      )
      expect(commands).to include(
        DiscourseWorkflows::Executor::RoutingCommand::Enqueue.new(
          node: target_node,
          items: [{ "json" => { "id" => 2 } }],
        ),
      )
    end
  end
end
