# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ExecutionPersistence do
  fab!(:workflow, :discourse_workflows_workflow)

  let(:trigger_data) { { "topic_id" => 1 } }
  let(:execution_context) do
    DiscourseWorkflows::Executor::ExecutionContext.new(
      workflow: workflow,
      trigger_data: trigger_data,
      user: nil,
    )
  end
  let(:steps_journal) { DiscourseWorkflows::Executor::StepsJournal.new }
  let(:persistence) do
    described_class.new(
      trigger_node_id: "node_1",
      execution_context: execution_context,
      steps_journal: steps_journal,
      execution_mode: :normal,
    )
  end

  describe "#start!" do
    it "creates the execution and seeds the resume token" do
      execution = persistence.start!

      expect(execution).to be_present
      expect(execution_context.execution).to eq(execution)
      expect(execution_context.resume_token).to be_present
      expect(execution_context.context["trigger"]).to eq(trigger_data)
    end
  end

  describe "#save!" do
    before { persistence.start! }

    it "persists entries and context to execution_data" do
      execution_context.store_context("node_a", [{ "json" => { "x" => 1 } }])
      steps_journal.record_step(
        "node_a",
        {
          "node_id" => "1",
          "node_name" => "Node A",
          "node_type" => "action:code",
          "position" => 0,
          "input" => [],
          "status" => "success",
        },
      )

      persistence.save!

      parsed = JSON.parse(persistence.execution.execution_data.data)
      expect(parsed["context"]["node_a"]).to eq([{ "json" => { "x" => 1 } }])
      expect(parsed["entries"]["node_a"]).to be_present
    end

    it "truncates context when data exceeds max size" do
      execution_context.store_context("big_data", "x" * 6.megabytes)

      persistence.save!(max_size: 5.megabytes)
      parsed = JSON.parse(persistence.execution.execution_data.data)

      expect(parsed["context"]).to eq({ "__truncated" => true })
    end
  end

  describe "#resume!" do
    it "restores journal state, context, and workflow snapshot data" do
      persistence.start!
      execution_context.store_context("node_a", "data_a")
      steps_journal.record_step(
        "node_a",
        {
          "node_id" => "1",
          "node_name" => "Node A",
          "node_type" => "action:code",
          "position" => 0,
          "input" => [],
          "status" => "waiting",
        },
      )
      persistence.save!
      persistence.execution.update!(
        status: :waiting,
        waiting_node_id: "1",
        waiting_config: {
          "node_contexts" => {
            "node_a" => {
              "counter" => 1,
            },
          },
          "step_position" => 1,
        },
      )

      restored_context =
        DiscourseWorkflows::Executor::ExecutionContext.new(
          workflow: workflow,
          trigger_data: trigger_data,
          user: nil,
        )
      restored_journal = DiscourseWorkflows::Executor::StepsJournal.new
      restored =
        described_class.new(
          trigger_node_id: "node_1",
          execution_context: restored_context,
          steps_journal: restored_journal,
          execution_mode: :normal,
        )

      restored.resume!(persistence.execution)

      expect(restored_context.context).to include("node_a" => "data_a")
      expect(restored_context.node_context_for(OpenStruct.new(name: "node_a"))).to eq(
        "counter" => 1,
      )
      expect(restored_journal.next_step_position).to eq(1)
      expect(restored.workflow_snapshot_data).to be_present
    end
  end
end
