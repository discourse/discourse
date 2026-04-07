# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::NodeRouter do
  def build_node(id: "1", type: "action:test", name: "test_node", configuration: {})
    DiscourseWorkflows::WorkflowSnapshot::SnapshotNode.new(
      id: id,
      type: type,
      type_version: "1.0",
      name: name,
      position: {
        "x" => 0,
        "y" => 0,
      },
      configuration: configuration,
    )
  end

  def build_snapshot(nodes: [], connections: [])
    data = {
      "nodes" =>
        nodes.map do |n|
          {
            "id" => n.id,
            "type" => n.type,
            "type_version" => n.type_version,
            "name" => n.name,
            "configuration" => n.configuration,
          }
        end,
      "connections" => connections,
    }
    DiscourseWorkflows::WorkflowSnapshot.new(data)
  end

  def stub_node_type_class(outputs: [:main])
    klass =
      Class.new do
        extend DiscourseWorkflows::NodeTypeDescriptor

        attr_reader :configuration, :log, :expression_errors, :condition_details, :resolved_config

        def initialize(configuration: {})
          @configuration = configuration
          @log = DiscourseWorkflows::StepLog.new
          @expression_errors = []
          @condition_details = nil
        end

        def execute(exec_ctx)
          [exec_ctx.input_items]
        end
      end
    klass.define_singleton_method(:outputs) { outputs }
    klass
  end

  let(:state) do
    state = instance_double(DiscourseWorkflows::Executor::ExecutionState)
    allow(state).to receive(:next_step_position).and_return(0, 1, 2, 3, 4, 5)
    allow(state).to receive(:record_step)
    allow(state).to receive(:resolver_context).and_return({})
    allow(state).to receive(:user).and_return(nil)
    allow(state).to receive(:shared_sandbox).and_return(nil)
    allow(state).to receive(:preloaded_vars).and_return({})
    allow(state).to receive(:node_context_for).and_return({})
    workflow_double = instance_double(DiscourseWorkflows::Workflow, id: 1)
    allow(state).to receive(:workflow).and_return(workflow_double)
    state
  end

  let(:step_runner) { DiscourseWorkflows::Executor::StepRunner.new(state) }
  let(:run_as_user_proc) { -> { Discourse.system_user } }

  RoutingCommand = DiscourseWorkflows::Executor::RoutingCommand

  describe "#execute_node" do
    it "returns RecordStep command for unknown node types" do
      node = build_node(type: "action:nonexistent")
      snapshot = build_snapshot
      router =
        described_class.new(
          state: state,
          step_runner: step_runner,
          snapshot: snapshot,
          user: nil,
          run_as_user_proc: run_as_user_proc,
        )

      allow(DiscourseWorkflows::Registry).to receive(:find_node_type).and_return(nil)

      commands = router.execute_node(node, [{ "json" => {} }])

      expect(commands).to contain_exactly(an_instance_of(RoutingCommand::RecordStep))
      cmd = commands.first
      expect(cmd.node_name).to eq("test_node")
      expect(cmd.step).to be_error
      expect(cmd.step.error).to eq("Unknown node type 'action:nonexistent'")
    end

    it "returns StoreContext and Enqueue commands for single-output nodes" do
      node = build_node(id: "1", type: "action:test", name: "action1")
      target_node = build_node(id: "2", type: "action:test", name: "action2")
      snapshot =
        build_snapshot(
          nodes: [node, target_node],
          connections: [
            { "source_node_id" => "1", "source_output" => "main", "target_node_id" => "2" },
          ],
        )
      node_type_class = stub_node_type_class

      allow(DiscourseWorkflows::Registry).to receive(:find_node_type).and_return(node_type_class)

      router =
        described_class.new(
          state: state,
          step_runner: step_runner,
          snapshot: snapshot,
          user: nil,
          run_as_user_proc: run_as_user_proc,
        )
      input_items = [{ "json" => { "x" => 1 } }]
      commands = router.execute_node(snapshot.find_node("1"), input_items)

      store_cmd = commands.find { |c| c.is_a?(RoutingCommand::StoreContext) }
      enqueue_cmd = commands.find { |c| c.is_a?(RoutingCommand::Enqueue) }

      expect(store_cmd.name).to eq("action1")
      expect(store_cmd.items).to eq(input_items)
      expect(enqueue_cmd.node.id).to eq("2")
      expect(enqueue_cmd.items).to eq(input_items)
    end

    it "returns no commands when all output arrays are empty" do
      node = build_node(id: "1", type: "condition:filter", name: "filter")
      target_node = build_node(id: "2", type: "action:test", name: "downstream")
      snapshot =
        build_snapshot(
          nodes: [node, target_node],
          connections: [
            { "source_node_id" => "1", "source_output" => "main", "target_node_id" => "2" },
          ],
        )
      outputs = [{ key: "true", label_key: "t" }, { key: "false", label_key: "f" }]
      filtering_class = stub_node_type_class(outputs: outputs)
      filtering_class.define_method(:execute) { |exec_ctx| [[], []] }

      allow(DiscourseWorkflows::Registry).to receive(:find_node_type).and_return(filtering_class)

      router =
        described_class.new(
          state: state,
          step_runner: step_runner,
          snapshot: snapshot,
          user: nil,
          run_as_user_proc: run_as_user_proc,
        )
      commands = router.execute_node(snapshot.find_node("1"), [{ "json" => {} }])

      expect(commands).to be_empty
    end

    it "routes branching outputs to correct downstream nodes by port index" do
      node = build_node(id: "1", type: "condition:switch", name: "switch")
      true_target = build_node(id: "2", type: "action:test", name: "true_branch")
      false_target = build_node(id: "3", type: "action:test", name: "false_branch")
      snapshot =
        build_snapshot(
          nodes: [node, true_target, false_target],
          connections: [
            { "source_node_id" => "1", "source_output" => "true", "target_node_id" => "2" },
            { "source_node_id" => "1", "source_output" => "false", "target_node_id" => "3" },
          ],
        )

      true_items = [{ "json" => { "pass" => true } }]
      false_items = [{ "json" => { "pass" => false } }]
      outputs = [{ key: "true", label_key: "t" }, { key: "false", label_key: "f" }]
      branching_class = stub_node_type_class(outputs: outputs)
      branching_class.define_method(:execute) { |exec_ctx| [true_items, false_items] }

      allow(DiscourseWorkflows::Registry).to receive(:find_node_type).and_return(branching_class)

      router =
        described_class.new(
          state: state,
          step_runner: step_runner,
          snapshot: snapshot,
          user: nil,
          run_as_user_proc: run_as_user_proc,
        )
      commands = router.execute_node(snapshot.find_node("1"), [{ "json" => {} }])

      enqueue_cmds = commands.select { |c| c.is_a?(RoutingCommand::Enqueue) }
      expect(enqueue_cmds.find { |c| c.node.id == "2" }.items).to eq(true_items)
      expect(enqueue_cmds.find { |c| c.node.id == "3" }.items).to eq(false_items)
    end

    it "flattens all outputs for StoreContext" do
      node = build_node(id: "1", type: "action:split", name: "splitter")
      branch_a = build_node(id: "2", type: "action:test", name: "branch_a")
      branch_b = build_node(id: "3", type: "action:test", name: "branch_b")
      snapshot =
        build_snapshot(
          nodes: [node, branch_a, branch_b],
          connections: [
            { "source_node_id" => "1", "source_output" => "a", "target_node_id" => "2" },
            { "source_node_id" => "1", "source_output" => "b", "target_node_id" => "3" },
          ],
        )

      a_items = [{ "json" => { "x" => 1 } }]
      b_items = [{ "json" => { "x" => 2 } }]
      outputs = [{ key: "a", label_key: "a" }, { key: "b", label_key: "b" }]
      branching_class = stub_node_type_class(outputs: outputs)
      branching_class.define_method(:execute) { |exec_ctx| [a_items, b_items] }

      allow(DiscourseWorkflows::Registry).to receive(:find_node_type).and_return(branching_class)

      router =
        described_class.new(
          state: state,
          step_runner: step_runner,
          snapshot: snapshot,
          user: nil,
          run_as_user_proc: run_as_user_proc,
        )
      commands = router.execute_node(snapshot.find_node("1"), [{ "json" => {} }])

      store_cmd = commands.find { |c| c.is_a?(RoutingCommand::StoreContext) }
      enqueue_cmds = commands.select { |c| c.is_a?(RoutingCommand::Enqueue) }

      expect(store_cmd.name).to eq("splitter")
      expect(store_cmd.items).to eq(a_items + b_items)
      expect(enqueue_cmds.map { |c| c.node.id }).to contain_exactly("2", "3")
    end

    it "raises on error outcome" do
      node = build_node(id: "1", type: "action:test", name: "error_node")
      snapshot = build_snapshot(nodes: [node])

      error_class = stub_node_type_class
      error_class.define_method(:execute) { |exec_ctx| raise "node error" }

      allow(DiscourseWorkflows::Registry).to receive(:find_node_type).and_return(error_class)

      router =
        described_class.new(
          state: state,
          step_runner: step_runner,
          snapshot: snapshot,
          user: nil,
          run_as_user_proc: run_as_user_proc,
        )

      expect { router.execute_node(snapshot.find_node("1"), [{ "json" => {} }]) }.to raise_error(
        RuntimeError,
        "node error",
      )
    end

    it "returns Pause command for wait outcome" do
      node = build_node(id: "1", type: "action:test", name: "wait_node")
      snapshot = build_snapshot(nodes: [node])

      wait_class = stub_node_type_class
      wait_error = DiscourseWorkflows::WaitForWebhook.new
      wait_class.define_method(:execute) { |exec_ctx| raise wait_error }

      allow(DiscourseWorkflows::Registry).to receive(:find_node_type).and_return(wait_class)

      router =
        described_class.new(
          state: state,
          step_runner: step_runner,
          snapshot: snapshot,
          user: nil,
          run_as_user_proc: run_as_user_proc,
        )
      commands = router.execute_node(snapshot.find_node("1"), [{ "json" => {} }])

      expect(commands).to contain_exactly(an_instance_of(RoutingCommand::Pause))
      pause = commands.first
      expect(pause.node.id).to eq("1")
      expect(pause.error).to be_a(DiscourseWorkflows::WaitForResume)
    end
  end

  describe "#record_trigger_step" do
    it "records a step with position 0 and success status" do
      node = build_node(type: "trigger:webhook", name: "webhook_trigger")
      snapshot = build_snapshot(nodes: [node])

      allow(state).to receive(:record_step)

      router =
        described_class.new(
          state: state,
          step_runner: step_runner,
          snapshot: snapshot,
          user: nil,
          run_as_user_proc: run_as_user_proc,
        )
      items = [{ "json" => { "event" => "test" } }]

      router.record_trigger_step(node, items)

      expect(state).to have_received(:record_step).with(
        "webhook_trigger",
        an_object_having_attributes(
          node_type: "trigger:webhook",
          position: 0,
          status: "success",
          input: [],
          output: items,
        ),
      )
    end
  end

  describe "#enqueue_downstream" do
    it "follows connections from node and enqueues targets" do
      source = build_node(id: "1", name: "source")
      target = build_node(id: "2", name: "target")
      snapshot =
        build_snapshot(
          nodes: [source, target],
          connections: [
            { "source_node_id" => "1", "source_output" => "main", "target_node_id" => "2" },
          ],
        )

      allow(state).to receive(:enqueue)

      router =
        described_class.new(
          state: state,
          step_runner: step_runner,
          snapshot: snapshot,
          user: nil,
          run_as_user_proc: run_as_user_proc,
        )
      items = [{ "json" => {} }]

      router.enqueue_downstream(snapshot.find_node("1"), "main", items)

      expect(state).to have_received(:enqueue).with(satisfy { |n| n.id == "2" }, items)
    end

    it "skips connections that don't match the output name" do
      source = build_node(id: "1", name: "source")
      target = build_node(id: "2", name: "target")
      snapshot =
        build_snapshot(
          nodes: [source, target],
          connections: [
            { "source_node_id" => "1", "source_output" => "true", "target_node_id" => "2" },
          ],
        )

      allow(state).to receive(:enqueue)

      router =
        described_class.new(
          state: state,
          step_runner: step_runner,
          snapshot: snapshot,
          user: nil,
          run_as_user_proc: run_as_user_proc,
        )

      router.enqueue_downstream(snapshot.find_node("1"), "false", [{ "json" => {} }])

      expect(state).not_to have_received(:enqueue)
    end
  end
end
