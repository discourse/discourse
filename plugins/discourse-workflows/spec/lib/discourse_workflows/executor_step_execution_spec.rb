# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)

  def build_chain_workflow
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:post_created", name: "Post Created"
        g.node "set-1",
               "action:set_fields",
               name: "Set 1",
               configuration: {
                 "mode" => "raw",
                 "include_other_fields" => true,
                 "json_output" => '{"a": 1}',
               }
        g.node "set-2",
               "action:set_fields",
               name: "Set 2",
               configuration: {
                 "mode" => "raw",
                 "include_other_fields" => true,
                 "json_output" => '{"b": 2}',
               }
        g.node "set-3",
               "action:set_fields",
               name: "Set 3",
               configuration: {
                 "mode" => "raw",
                 "include_other_fields" => true,
                 "json_output" => '{"c": 3}',
               }
        g.chain "trigger-1", "set-1", "set-2", "set-3"
      end
    Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)
  end

  let(:workflow) { build_chain_workflow }

  let(:manual_options) do
    DiscourseWorkflows::Executor::ExecutionOptions.new(
      user: user,
      execution_mode: :manual,
      draft_execution: true,
    )
  end

  def run_full_execution(workflow)
    described_class.new(workflow, "trigger-1", { "seed" => true }, manual_options).run
  end

  def create_step_execution(workflow, node_id, source: nil)
    DiscourseWorkflows::Execution.create_pending_step!(
      workflow: workflow,
      node_id: node_id,
      trigger_data: source&.trigger_data || {},
      run_data: source ? source.execution_data.run_data : {},
    )
  end

  def run_step_execution(workflow, node_id, source: nil)
    step_execution = create_step_execution(workflow, node_id, source: source)
    claimed = DiscourseWorkflows::Execution.claim_pending(step_execution)
    options =
      DiscourseWorkflows::Executor::ExecutionOptions.new(
        user: user,
        execution_mode: :manual,
        workflow_snapshot:
          DiscourseWorkflows::WorkflowSnapshot.new(step_execution.execution_data.workflow_data),
        existing_execution: claimed,
        step_node_id: node_id,
      )
    described_class.new(workflow, node_id, claimed.trigger_data, options).run
  end

  def seeded_output(source, node_name)
    source.execution_data.run_data[node_name].first["outputs"].first["items"]
  end

  describe "step execution over seeded run data" do
    it "executes only the target node when driven through the manual workflow job" do
      source = run_full_execution(workflow)
      step_execution = create_step_execution(workflow, "set-2", source: source)

      Jobs::DiscourseWorkflows::ExecuteManualWorkflow.new.execute(
        execution_id: step_execution.id,
        user_id: user.id,
        step_node_id: "set-2",
      )

      step_execution.reload
      expect(step_execution.status).to eq("success")
      entries = step_execution.execution_data.entries
      expect(entries.keys).to contain_exactly("set-1", "set-2")
      expect(entries["set-1"].first.dig("metadata", "cached")).to eq(true)
      expect(step_execution.execution_data.run_data["Set 1"].length).to eq(1)
      expect(step_execution.execution_data.run_data["Set 3"].length).to eq(1)
    end

    it "reuses the cached frontier and executes only the target" do
      source = run_full_execution(workflow)

      execution = run_step_execution(workflow, "set-3", source: source)

      entries = execution.execution_data.entries
      expect(entries.keys).to contain_exactly("set-2", "set-3")
      expect(entries["set-2"].first.dig("metadata", "cached")).to eq(true)
      expect(entries["set-3"].first["input"]).to eq(seeded_output(source, "Set 2"))
    end

    it "feeds the target node the upstream output recorded in the seeded run data" do
      source = run_full_execution(workflow)

      execution = run_step_execution(workflow, "set-2", source: source)

      entry = execution.execution_data.entries["set-2"].first
      expect(entry["input"]).to eq(seeded_output(source, "Set 1"))

      new_run = execution.execution_data.run_data["Set 2"].last
      expect(new_run["inputs"].first["items"]).to eq(seeded_output(source, "Set 1"))
      expect(new_run["inputs"].first["source"]).to eq("node_name" => "Set 1", "output_index" => 0)
      expect(entry["output"].first["json"]).to include("seed" => true, "a" => 1, "b" => 2)
    end

    it "persists the union of the seeded runs and the new step run" do
      source = run_full_execution(workflow)

      execution = run_step_execution(workflow, "set-2", source: source)

      run_data = execution.execution_data.run_data
      expect(run_data.keys).to contain_exactly("Post Created", "Set 1", "Set 2", "Set 3")
      expect(run_data["Post Created"].length).to eq(1)
      expect(run_data["Set 1"].length).to eq(1)
      expect(run_data["Set 3"].length).to eq(1)
      expect(run_data["Set 2"].length).to eq(2)
      expect(run_data["Set 2"].last["outputs"].first["items"].first["json"]).to include(
        "seed" => true,
        "a" => 1,
        "b" => 2,
      )
    end

    it "publishes the union of seeded and new run data over MessageBus" do
      source = run_full_execution(workflow)

      messages =
        MessageBus.track_publish("/discourse-workflows/workflow/#{workflow.id}") do
          run_step_execution(workflow, "set-2", source: source)
        end

      message = messages.find { |m| m.data[:type] == "execution_completed" }
      expect(message.data[:lastExecutionRunData].keys).to contain_exactly(
        "Post Created",
        "Set 1",
        "Set 2",
        "Set 3",
      )
      expect(message.data[:lastExecutionRunData]["Set 2"].length).to eq(2)
    end
  end

  describe "step execution with pin data" do
    it "prefers pinned data on the upstream node over the seeded run output" do
      source = run_full_execution(workflow)
      workflow.update_node_pin_data!("Set 1", [{ "json" => { "pinned" => true } }])

      execution = run_step_execution(workflow, "set-2", source: source)

      entry = execution.execution_data.entries["set-2"].first
      expect(entry["input"].map { |item| item["json"] }).to eq([{ "pinned" => true }])
      expect(entry["output"].first["json"]).to include("pinned" => true, "b" => 2)
    end

    it "executes the target node for real even when it has its own pinned data" do
      source = run_full_execution(workflow)
      workflow.update_node_pin_data!("Set 2", [{ "json" => { "frozen" => true } }])

      execution = run_step_execution(workflow, "set-2", source: source)

      entry = execution.execution_data.entries["set-2"].first
      expect(entry["output"].first["json"]).to include("seed" => true, "a" => 1, "b" => 2)
      expect(entry["output"].first["json"]).not_to have_key("frozen")
      expect(entry.dig("metadata", "pinned")).to be_nil
    end
  end

  describe "step execution downstream of a false branch" do
    it "feeds the target the filtered run's false-port output" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:post_created", name: "Post Created"
          g.node "if-1",
                 "condition:if",
                 name: "If",
                 configuration: {
                   "conditions" => [
                     {
                       "id" => "1",
                       "leftValue" => 1,
                       "rightValue" => 2,
                       "operator" => {
                         "type" => "number",
                         "operation" => "equals",
                       },
                     },
                   ],
                   "combinator" => "and",
                 }
          g.node "set-1",
                 "action:set_fields",
                 name: "On false",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => true,
                   "json_output" => '{"handled": true}',
                 }
          g.chain "trigger-1", "if-1"
          g.connect "if-1", "set-1", output: "false"
        end
      branch_workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      source = run_full_execution(branch_workflow)
      if_run = source.execution_data.run_data["If"].first
      expect(if_run["status"]).to eq("filtered")

      execution = run_step_execution(branch_workflow, "set-1", source: source)

      expect(execution.status).to eq("success")
      entry = execution.execution_data.entries["set-1"].first
      expect(entry["input"]).to eq(if_run["outputs"].last["items"])
      expect(entry["output"].first["json"]).to include("seed" => true, "handled" => true)

      new_run = execution.execution_data.run_data["On false"].last
      expect(new_run["inputs"].first["source"]).to eq("node_name" => "If", "output_index" => 1)
    end
  end

  describe "step execution with stale seeded run data" do
    it "re-executes a node whose cached runs belong to a different node id" do
      source = run_full_execution(workflow)
      stale_run_data = source.execution_data.run_data.deep_dup
      stale_run_data["Set 1"].each { |run| run["node_id"] = "recreated-set-1" }

      step_execution =
        DiscourseWorkflows::Execution.create_pending_step!(
          workflow: workflow,
          node_id: "set-2",
          trigger_data: source.trigger_data,
          run_data: stale_run_data,
        )
      claimed = DiscourseWorkflows::Execution.claim_pending(step_execution)
      options =
        DiscourseWorkflows::Executor::ExecutionOptions.new(
          user: user,
          execution_mode: :manual,
          workflow_snapshot:
            DiscourseWorkflows::WorkflowSnapshot.new(step_execution.execution_data.workflow_data),
          existing_execution: claimed,
          step_node_id: "set-2",
        )
      execution = described_class.new(workflow, "set-2", claimed.trigger_data, options).run

      expect(execution.status).to eq("success")
      entries = execution.execution_data.entries
      expect(entries.keys).to contain_exactly("trigger-1", "set-1", "set-2")
      expect(entries["trigger-1"].first.dig("metadata", "cached")).to eq(true)
      expect(entries["set-2"].first["input"]).to eq(entries["set-1"].first["output"])

      run_data = execution.execution_data.run_data
      expect(run_data["Set 1"].length).to eq(1)
      expect(run_data["Set 1"].first["node_id"]).to eq("set-1")
    end
  end

  describe "step execution without cached upstream data" do
    it "runs the un-cached upstream chain up to the target" do
      workflow.update_node_pin_data!("Post Created", [{ "json" => { "cold" => true } }])

      execution = run_step_execution(workflow, "set-2")

      expect(execution.status).to eq("success")
      entries = execution.execution_data.entries
      expect(entries.keys).to contain_exactly("trigger-1", "set-1", "set-2")
      expect(entries["trigger-1"].first.dig("metadata", "cached")).to eq(true)
      expect(entries["set-2"].first["output"].first["json"]).to include(
        "cold" => true,
        "a" => 1,
        "b" => 2,
      )
    end

    it "seeds an un-cached manually triggerable trigger" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual", name: "Manual"
          g.node "set-1",
                 "action:set_fields",
                 name: "Set 1",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => true,
                   "json_output" => '{"a": 1}',
                 }
          g.chain "trigger-1", "set-1"
        end
      manual_workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = run_step_execution(manual_workflow, "set-1")

      expect(execution.status).to eq("success")
      entries = execution.execution_data.entries
      expect(entries.keys).to contain_exactly("trigger-1", "set-1")
      expect(entries["trigger-1"].first.dig("metadata", "cached")).to be_nil
      expect(entries["set-1"].first["input"]).to eq([{ "json" => {} }])
    end
  end

  describe "consecutive step executions" do
    it "feeds later step runs the latest output of earlier ones" do
      source = run_full_execution(workflow)
      update_workflow_node(workflow, "set-1") do |node|
        node["parameters"] = node["parameters"].merge("json_output" => '{"a": 2}')
        node
      end

      first = run_step_execution(workflow, "set-1", source: source)
      first_run = first.execution_data.run_data["Set 1"].last
      expect(first_run["status"]).to eq("success")
      expect(first_run["node_id"]).to eq("set-1")

      second = run_step_execution(workflow, "set-2", source: first)
      expect(second.execution_data.entries["set-2"].first["input"].first["json"]).to include(
        "a" => 2,
      )
    end
  end

  describe "step execution of a node with no inbound connections" do
    it "executes with a single empty input item" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:post_created", name: "Post Created"
          g.node "solo-1",
                 "action:set_fields",
                 name: "Solo",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => true,
                   "json_output" => '{"solo": true}',
                 }
        end
      standalone_workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = run_step_execution(standalone_workflow, "solo-1")

      expect(execution.status).to eq("success")
      entry = execution.execution_data.entries["solo-1"].first
      expect(entry["input"]).to eq([{ "json" => {} }])
      expect(entry["output"].first["json"]).to eq("solo" => true)
    end
  end

  describe "step execution of a node requesting a wait" do
    it "fails the execution instead of pausing it" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:post_created", name: "Post Created"
          g.node "wait-1",
                 "flow:wait",
                 name: "Wait",
                 configuration: {
                   "resume" => "time_interval",
                   "wait_amount" => 1,
                   "wait_unit" => "seconds",
                 }
        end
      wait_workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = run_step_execution(wait_workflow, "wait-1")

      expect(execution.status).to eq("error")
      expect(execution.error).to eq(
        I18n.t("discourse_workflows.errors.step_execution.wait_requested"),
      )
    end
  end
end
