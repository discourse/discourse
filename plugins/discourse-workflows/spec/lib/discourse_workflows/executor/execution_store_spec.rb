# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ExecutionStore do
  fab!(:workflow, :discourse_workflows_workflow)

  let(:trigger_data) { { "topic_id" => 1 } }
  let(:execution_context) do
    DiscourseWorkflows::Executor::ExecutionContext.new(
      workflow: workflow,
      trigger_data: trigger_data,
      user: nil,
    )
  end
  let(:options) { DiscourseWorkflows::Executor::ExecutionOptions.new }
  let(:store) do
    described_class.new(
      trigger_node_id: "node_1",
      execution_context: execution_context,
      execution_mode: :normal,
      options: options,
    )
  end

  describe "#start!" do
    it "creates the execution and seeds the resume token" do
      execution = store.start!

      expect(execution).to be_present
      expect(execution_context.execution).to eq(execution)
      expect(execution_context.resume_token).to be_present
      expect(execution_context.context["$trigger"]).to eq(trigger_data)
    end
  end

  describe "#publish_progress" do
    it "publishes a compact step update to the admin-secured execution channel" do
      execution = store.start!
      step =
        DiscourseWorkflows::Executor::Step.build(
          node: OpenStruct.new(id: "1", name: "Node A", type: "action:code", typeVersion: "1.0"),
          position: 0,
          input: [{ "json" => { "secret" => "not published" } }],
        )

      messages =
        MessageBus.track_publish("/discourse-workflows/execution/#{execution.id}") do
          store.publish_progress(step: step)
        end

      expect(messages.length).to eq(1)
      expect(messages.first.group_ids).to eq([Group::AUTO_GROUPS[:admins]])
      payload = messages.first.data
      expect(payload).to include(type: "execution_progress", refresh: false)
      expect(payload[:execution]).to include(id: execution.id, status: "running")
      expect(payload[:step]).to include(
        "node_id" => "1",
        "node_name" => "Node A",
        "status" => "running",
      )
      expect(messages.first.data.to_json).not_to include("not published")
    end
    it "publishes terminal state after persistence" do
      execution = store.start!

      messages =
        MessageBus.track_publish("/discourse-workflows/execution/#{execution.id}") do
          store.finish!(steps: [])
        end

      expect(messages.length).to eq(1)
      expect(messages.first.data).to include(type: "execution_progress", refresh: true)
      expect(messages.first.data[:execution]).to include(
        id: execution.id,
        status: "success",
        finished_at: be_present,
      )
    end
  end

  describe "#save! via finish!" do
    before { store.start! }

    it "persists entries and context to execution_data" do
      execution_context.store_context("node_a", [{ "json" => { "x" => 1 } }])
      steps = [
        DiscourseWorkflows::Executor::Step.build(
          node: OpenStruct.new(id: "1", name: "Node A", type: "action:code", typeVersion: "1.0"),
          position: 0,
          input: [],
          status: DiscourseWorkflows::Executor::Step::SUCCESS,
        ),
      ]

      store.finish!(steps: steps)

      parsed = store.execution.execution_data.data
      expect(parsed["context"]["node_a"]).to eq([{ "json" => { "x" => 1 } }])
      expect(parsed["entries"]["1"]).to be_present
    end

    it "persists canonical run data grouped by node and output index" do
      node = OpenStruct.new(id: "1", name: "Node A", type: "action:code", typeVersion: "1.0")
      output_groups = [[{ "json" => { "value" => 1 } }], [{ "json" => { "alternate" => true } }]]
      input_groups = [[{ "json" => { "input" => true } }]]
      execution_context.store_node_run(
        node,
        inputs: input_groups,
        outputs: output_groups,
        input_sources: [{ "node_name" => "Trigger", "output_index" => 0 }],
      )
      steps = [
        DiscourseWorkflows::Executor::Step.build(
          node: node,
          position: 0,
          input: input_groups.first,
          status: DiscourseWorkflows::Executor::Step::SUCCESS,
          output: output_groups.flatten(1),
        ),
      ]

      messages =
        MessageBus.track_publish("/discourse-workflows/workflow/#{workflow.id}") do
          store.finish!(steps: steps)
        end

      expect(messages.length).to eq(1)
      payload = messages.first.data
      expect(messages.first.group_ids).to eq([Group::AUTO_GROUPS[:admins]])
      expect(payload[:type]).to eq("execution_completed")
      published_run = payload.dig(:lastExecutionRunData, "Node A", 0)
      expect(published_run).to include("node_name" => "Node A")
      expect(published_run["outputs"]).to include(
        hash_including("index" => 0, "item_count" => 1),
        hash_including("index" => 1, "item_count" => 1),
      )

      run = store.execution.execution_data.run_data.dig("Node A", 0)
      expect(run).to include(
        "node_id" => "1",
        "node_name" => "Node A",
        "node_type" => "action:code",
        "status" => "success",
        "run_index" => 0,
      )
      expect(run.dig("inputs", 0, "source")).to eq("node_name" => "Trigger", "output_index" => 0)
      expect(run.dig("outputs", 0, "items", 0, "json")).to eq("value" => 1)
      expect(run.dig("outputs", 1, "items", 0, "json")).to eq("alternate" => true)
    end

    it "truncates oversized step strings before persistence" do
      stub_const(described_class, :MAX_STEP_STRING_BYTES, 10) do
        steps = [
          DiscourseWorkflows::Executor::Step.build(
            node: OpenStruct.new(id: "1", name: "Node A", type: "action:code", typeVersion: "1.0"),
            position: 0,
            input: [{ "json" => { "body" => "x" * 100 } }],
            status: DiscourseWorkflows::Executor::Step::SUCCESS,
            output: [{ "json" => { "body" => "y" * 100 } }],
          ),
        ]

        store.finish!(steps: steps)

        entry = store.execution.execution_data.data.dig("entries", "1", 0)
        expect(entry.dig("input", 0, "json", "body")).to include(
          "__truncated" => true,
          "__reason" => "step_string_size_limit",
          "__original_bytes" => 100,
          "preview" => "x" * 10,
        )
        expect(entry.dig("output", 0, "json", "body")).to include(
          "__truncated" => true,
          "__reason" => "step_string_size_limit",
          "__original_bytes" => 100,
          "preview" => "y" * 10,
        )
      end
    end

    it "summarizes step input and output that still exceed the per-field size limit" do
      stub_const(described_class, :MAX_STEP_IO_SIZE, 250) do
        stub_const(described_class, :MAX_STEP_STRING_BYTES, 1.kilobyte) do
          steps = [
            DiscourseWorkflows::Executor::Step.build(
              node:
                OpenStruct.new(id: "1", name: "Node A", type: "action:code", typeVersion: "1.0"),
              position: 0,
              input: [{ "json" => { "body" => "x" * 500 } }],
              status: DiscourseWorkflows::Executor::Step::SUCCESS,
              output: [{ "json" => { "body" => "y" * 500 } }],
            ),
          ]

          store.finish!(steps: steps)

          entry = store.execution.execution_data.data.dig("entries", "1", 0)
          expect(entry["input"]).to include(
            "__truncated" => true,
            "__reason" => "step_io_size_limit",
            "__class" => "Array",
            "__max_bytes" => 250,
          )
          expect(entry["output"]).to include(
            "__truncated" => true,
            "__reason" => "step_io_size_limit",
            "__class" => "Array",
            "__max_bytes" => 250,
          )
        end
      end
    end

    it "compacts entries when bounded step data still exceeds the execution size limit" do
      stub_const(described_class, :MAX_EXECUTION_DATA_SIZE, 5.kilobytes) do
        steps =
          8.times.map do |index|
            DiscourseWorkflows::Executor::Step.build(
              node:
                OpenStruct.new(
                  id: "node-#{index}",
                  name: "Node #{index}",
                  type: "action:code",
                  typeVersion: "1.0",
                ),
              position: index,
              input: [{ "json" => { "body" => "x" * 1000 } }],
              status: DiscourseWorkflows::Executor::Step::SUCCESS,
              output: [{ "json" => { "body" => "y" * 1000 } }],
            )
          end

        store.finish!(steps: steps)

        data = store.execution.execution_data.data
        entry = data.dig("entries", "node-0", 0)
        expect(data.to_json.bytesize).to be <= described_class::MAX_EXECUTION_DATA_SIZE
        expect(entry["input"]).to include(
          "__truncated" => true,
          "__reason" => "execution_data_size_limit",
        )
        expect(entry["output"]).to include(
          "__truncated" => true,
          "__reason" => "execution_data_size_limit",
        )
      end
    end
  end

  describe "wait-state cleanup" do
    let(:waiting_step) do
      DiscourseWorkflows::Executor::Step.build(
        node: OpenStruct.new(id: "1", name: "Node A", type: "action:code", typeVersion: "1.0"),
        position: 0,
        input: [],
        status: DiscourseWorkflows::Executor::Step::SUCCESS,
      )
    end

    before do
      store.start!
      store.execution.update!(
        status: :waiting,
        waiting_node_id: "1",
        waiting_until: 1.hour.from_now,
        resume_token: "stale-token",
        timeout_action: "fail",
      )
    end

    it "#finish! nils all wait-state columns" do
      store.finish!(steps: [waiting_step])

      expect(store.execution.reload).to have_attributes(
        status: "success",
        resume_token: nil,
        waiting_node_id: nil,
        waiting_until: nil,
        timeout_action: nil,
      )
    end

    it "#fail! nils all wait-state columns" do
      store.fail!(error: StandardError.new("boom"), steps: [waiting_step])

      expect(store.execution.reload).to have_attributes(
        status: "error",
        resume_token: nil,
        waiting_node_id: nil,
        waiting_until: nil,
        timeout_action: nil,
      )
    end

    context "with a draft execution" do
      let(:options) { DiscourseWorkflows::Executor::ExecutionOptions.new(draft_execution: true) }

      it "publishes completion data when the execution fails before node output exists" do
        messages =
          MessageBus.track_publish("/discourse-workflows/workflow/#{workflow.id}") do
            store.fail!(error: StandardError.new("boom"), steps: [])
          end

        expect(messages.length).to eq(1)
        payload = messages.first.data.deep_symbolize_keys
        expect(messages.first.group_ids).to eq([Group::AUTO_GROUPS[:admins]])
        expect(payload[:type]).to eq("execution_completed")
        expect(payload[:execution]).to include(
          id: store.execution.id,
          workflow_id: workflow.id,
          trigger_node_id: "node_1",
          status: "error",
        )
        expect(payload[:lastExecutionRunData]).to eq({})
      end
    end
  end

  describe "#resume!" do
    it "restores context and workflow snapshot data" do
      store.start!
      execution_context.store_context("node_a", "data_a")
      node = OpenStruct.new(id: "1", name: "Node A", type: "action:code", typeVersion: "1.0")
      output_groups = [[{ "json" => { "saved" => true } }]]
      execution_context.store_node_run(
        node,
        inputs: [[{ "json" => { "input" => true } }]],
        outputs: output_groups,
        input_sources: [{ "node_name" => "Trigger", "output_index" => 0 }],
      )
      steps = [
        DiscourseWorkflows::Executor::Step.build(
          node: node,
          position: 0,
          input: [],
          status: DiscourseWorkflows::Executor::Step::WAITING,
          output: output_groups.first,
        ),
      ]
      store.finish!(steps: steps)
      existing_data = store.execution.execution_data.data.deep_dup
      existing_data["node_contexts"] = { "node_a" => { "counter" => 1 } }
      store.execution.execution_data.update!(data: existing_data)
      store.execution.update!(status: :waiting, waiting_node_id: "1")

      restored_context =
        DiscourseWorkflows::Executor::ExecutionContext.new(
          workflow: workflow,
          trigger_data: trigger_data,
          user: nil,
        )
      restored =
        described_class.new(
          trigger_node_id: "node_1",
          execution_context: restored_context,
          execution_mode: :normal,
          options: options,
        )

      restored.resume!(store.execution)

      expect(restored_context.context).to include("node_a" => "data_a")
      expect(
        restored_context.context.dig("__node_runs", "Node A", 0, "outputs", 0, 0, "json"),
      ).to eq("saved" => true)
      expect(restored_context.node_context_for(OpenStruct.new(id: "node_a", name: "node_a"))).to eq(
        "counter" => 1,
      )
      expect(restored.workflow_snapshot).to be_present
    end
  end
end
