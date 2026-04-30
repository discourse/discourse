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
      expect(execution_context.context["trigger"]).to eq(trigger_data)
    end
  end

  describe "#save! via finish!" do
    before { store.start! }

    it "persists entries and context to execution_data" do
      execution_context.store_context("node_a", [{ "json" => { "x" => 1 } }])
      steps = [
        DiscourseWorkflows::Executor::Step.build(
          node: OpenStruct.new(id: "1", name: "Node A", type: "action:code", type_version: "1.0"),
          position: 0,
          input: [],
          status: DiscourseWorkflows::Executor::Step::SUCCESS,
        ),
      ]

      store.finish!(steps: steps)

      parsed = JSON.parse(store.execution.execution_data.data)
      expect(parsed["context"]["node_a"]).to eq([{ "json" => { "x" => 1 } }])
      expect(parsed["entries"]["1"]).to be_present
    end

    it "truncates oversized step strings before persistence" do
      stub_const(described_class, :MAX_STEP_STRING_BYTES, 10) do
        steps = [
          DiscourseWorkflows::Executor::Step.build(
            node: OpenStruct.new(id: "1", name: "Node A", type: "action:code", type_version: "1.0"),
            position: 0,
            input: [{ "json" => { "body" => "x" * 100 } }],
            status: DiscourseWorkflows::Executor::Step::SUCCESS,
            output: [{ "json" => { "body" => "y" * 100 } }],
          ),
        ]

        store.finish!(steps: steps)

        entry = JSON.parse(store.execution.execution_data.data).dig("entries", "1", 0)
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
                OpenStruct.new(id: "1", name: "Node A", type: "action:code", type_version: "1.0"),
              position: 0,
              input: [{ "json" => { "body" => "x" * 500 } }],
              status: DiscourseWorkflows::Executor::Step::SUCCESS,
              output: [{ "json" => { "body" => "y" * 500 } }],
            ),
          ]

          store.finish!(steps: steps)

          entry = JSON.parse(store.execution.execution_data.data).dig("entries", "1", 0)
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
                  type_version: "1.0",
                ),
              position: index,
              input: [{ "json" => { "body" => "x" * 1000 } }],
              status: DiscourseWorkflows::Executor::Step::SUCCESS,
              output: [{ "json" => { "body" => "y" * 1000 } }],
            )
          end

        store.finish!(steps: steps)

        data = store.execution.execution_data.data
        entry = JSON.parse(data).dig("entries", "node-0", 0)
        expect(data.bytesize).to be <= described_class::MAX_EXECUTION_DATA_SIZE
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

  describe "#resume!" do
    it "restores context and workflow snapshot data" do
      store.start!
      execution_context.store_context("node_a", "data_a")
      steps = [
        DiscourseWorkflows::Executor::Step.build(
          node: OpenStruct.new(id: "1", name: "Node A", type: "action:code", type_version: "1.0"),
          position: 0,
          input: [],
          status: DiscourseWorkflows::Executor::Step::WAITING,
        ),
      ]
      store.finish!(steps: steps)
      existing_data = JSON.parse(store.execution.execution_data.data)
      existing_data["node_contexts"] = { "node_a" => { "counter" => 1 } }
      store.execution.execution_data.update!(data: existing_data.to_json)
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
      expect(restored_context.node_context_for(OpenStruct.new(id: "node_a", name: "node_a"))).to eq(
        "counter" => 1,
      )
      expect(restored.workflow_snapshot_data).to be_present
    end
  end
end
