# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::StepExecutionPlan do
  let(:plan_builder) { DiscourseWorkflows::StepExecutionPlanBuilder.new }

  let(:chain_graph) do
    build_workflow_graph do |g|
      g.node "trigger-1", "trigger:post_created", name: "Trigger"
      g.node "set-1", "action:set_fields", name: "Source"
      g.node "set-2", "action:set_fields", name: "Target"
      g.chain "trigger-1", "set-1", "set-2"
    end
  end

  let(:chain_snapshot) { plan_builder.snapshot(graph: chain_graph) }

  it "treats a node with no inbound connections as a reachable standalone target" do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_created", name: "Trigger"
        g.node "set-1", "action:set_fields", name: "Standalone"
      end

    snapshot = plan_builder.snapshot(graph: graph)
    plan = plan_builder.plan(snapshot: snapshot, node_id: "set-1")

    expect(plan).to be_standalone_target
    expect(plan).to be_target_reachable
  end

  it "reuses cached upstream runs and only executes the target" do
    run_data = { "Source" => [plan_builder.source_run(items: [{ "json" => { "value" => 1 } }])] }

    plan = plan_builder.plan(snapshot: chain_snapshot, node_id: "set-2", run_data: run_data)

    expect(plan.executable_nodes.map(&:id)).to contain_exactly("set-2")
    expect(plan.cached_frontier.map(&:id)).to contain_exactly("set-1")
    expect(plan.trigger_roots_to_run).to be_empty
    expect(plan).to be_target_reachable
    expect(plan.cached_outputs(chain_snapshot.find_node("set-1"))).to eq(
      [[{ "json" => { "value" => 1 } }]],
    )
  end

  it "always executes the target even when it has cached data" do
    run_data = {
      "Source" => [plan_builder.source_run(items: [{ "json" => { "a" => 1 } }])],
      "Target" => [plan_builder.source_run(items: [{ "json" => { "b" => 2 } }], node_id: "set-2")],
    }

    plan = plan_builder.plan(snapshot: chain_snapshot, node_id: "set-2", run_data: run_data)

    expect(plan.executable_nodes.map(&:id)).to contain_exactly("set-2")
  end

  it "is unreachable when the chain is cold and the trigger cannot run manually" do
    plan = plan_builder.plan(snapshot: chain_snapshot, node_id: "set-2")

    expect(plan).not_to be_target_reachable
  end

  it "executes the whole un-cached chain from a pinned trigger" do
    snapshot =
      plan_builder.snapshot(
        graph: chain_graph,
        pin_data: {
          "Trigger" => [{ "json" => { "pinned" => true } }],
        },
      )

    plan = plan_builder.plan(snapshot: snapshot, node_id: "set-2")

    expect(plan).to be_target_reachable
    expect(plan.executable_nodes.map(&:id)).to contain_exactly("set-1", "set-2")
    expect(plan.cached_frontier.map(&:id)).to contain_exactly("trigger-1")
    expect(plan.trigger_roots_to_run).to be_empty
  end

  it "runs a manually triggerable trigger when nothing is cached" do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual", name: "Manual"
        g.node "set-1", "action:set_fields", name: "Target"
        g.chain "trigger-1", "set-1"
      end

    snapshot = plan_builder.snapshot(graph: graph)
    plan = plan_builder.plan(snapshot: snapshot, node_id: "set-1")

    expect(plan).to be_target_reachable
    expect(plan.trigger_roots_to_run.map(&:id)).to contain_exactly("trigger-1")
    expect(plan.executable_nodes.map(&:id)).to contain_exactly("trigger-1", "set-1")
  end

  it "reuses filtered branching runs including their secondary ports" do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_created", name: "Trigger"
        g.node "if-1", "condition:if", name: "If"
        g.node "set-1", "action:set_fields", name: "Target"
        g.chain "trigger-1", "if-1"
        g.connect "if-1", "set-1", output: "false"
      end
    items = [{ "json" => { "branched" => true } }]
    run_data = {
      "If" => [
        plan_builder.run(
          node_id: "if-1",
          node_type: "condition:if",
          status: "filtered",
          outputs: [
            plan_builder.port(index: 0, items: []),
            plan_builder.port(index: 1, items: items),
          ],
        ),
      ],
    }
    snapshot = plan_builder.snapshot(graph: graph)

    plan = plan_builder.plan(snapshot: snapshot, node_id: "set-1", run_data: run_data)

    expect(plan.executable_nodes.map(&:id)).to contain_exactly("set-1")
    expect(plan.cached_outputs(snapshot.find_node("if-1"))).to eq([[], items])
  end

  it "re-executes nodes whose cached runs belong to a different node identity" do
    run_data = {
      "Source" => [
        plan_builder.source_run(
          items: [{ "json" => { "stale" => true } }],
          node_id: "recreated-set-1",
        ),
      ],
    }
    snapshot =
      plan_builder.snapshot(
        graph: chain_graph,
        pin_data: {
          "Trigger" => [{ "json" => { "fresh" => true } }],
        },
      )

    plan = plan_builder.plan(snapshot: snapshot, node_id: "set-2", run_data: run_data)

    expect(plan.executable_nodes.map(&:id)).to contain_exactly("set-1", "set-2")
  end

  it "does not treat error runs as cache" do
    run_data = {
      "Source" => [plan_builder.source_run(items: [{ "json" => { "a" => 1 } }], status: "error")],
    }

    plan = plan_builder.plan(snapshot: chain_snapshot, node_id: "set-2", run_data: run_data)

    expect(plan).not_to be_target_reachable
  end

  context "with a merge node requiring a minimum number of inputs" do
    let(:merge_graph) do
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_created", name: "Trigger"
        g.node "set-a", "action:set_fields", name: "A"
        g.node "set-b", "action:set_fields", name: "B"
        g.node "merge-1", "flow:merge", name: "Merge"
        g.chain "trigger-1", "set-a"
        g.chain "trigger-1", "set-b"
        g.connect "set-a", "merge-1", input: "input_1"
        g.connect "set-b", "merge-1", input: "input_2"
      end
    end

    it "is reachable when one branch has data even though the other is dead" do
      snapshot =
        plan_builder.snapshot(graph: merge_graph, pin_data: { "A" => [{ "json" => { "a" => 1 } }] })

      plan = plan_builder.plan(snapshot: snapshot, node_id: "merge-1")

      expect(plan).to be_target_reachable
      expect(plan.cached_frontier.map(&:id)).to contain_exactly("set-a")
    end

    it "is unreachable when no branch can produce data" do
      snapshot = plan_builder.snapshot(graph: merge_graph)
      plan = plan_builder.plan(snapshot: snapshot, node_id: "merge-1")

      expect(plan).not_to be_target_reachable
    end
  end

  it "terminates on graphs with cycles" do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_created", name: "Trigger"
        g.node "set-a", "action:set_fields", name: "A"
        g.node "set-b", "action:set_fields", name: "B"
        g.chain "trigger-1", "set-a", "set-b"
        g.connect "set-b", "set-a"
      end
    snapshot =
      plan_builder.snapshot(
        graph: graph,
        pin_data: {
          "Trigger" => [{ "json" => { "go" => true } }],
        },
      )

    plan = plan_builder.plan(snapshot: snapshot, node_id: "set-b")

    expect(plan).to be_target_reachable
    expect(plan.executable_nodes.map(&:id)).to contain_exactly("set-a", "set-b")
  end
end
