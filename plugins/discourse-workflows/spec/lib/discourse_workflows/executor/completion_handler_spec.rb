# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::CompletionHandler do
  fab!(:user)

  let(:workflow) do
    Fabricate(
      :discourse_workflows_workflow,
      created_by: user,
      enabled: true,
      nodes: [
        {
          "id" => "trigger-1",
          "type" => "trigger:topic_closed",
          "type_version" => "1.0",
          "name" => "Topic Closed",
          "position" => {
            "x" => 0,
            "y" => 0,
          },
          "position_index" => 0,
          "configuration" => {
          },
        },
      ],
      connections: [],
    )
  end

  let(:options) { DiscourseWorkflows::Executor::ExecutionOptions.new }
  let(:trigger_data) { { "topic_id" => 1 } }

  let(:state) do
    DiscourseWorkflows::Executor::ExecutionState.new(
      workflow: workflow,
      trigger_node_id: "trigger-1",
      trigger_data: trigger_data,
      options: options,
    )
  end

  let(:handler) { described_class.new(state: state, options: options) }

  before { SiteSetting.discourse_workflows_enabled = true }

  describe "#finish!" do
    before { state.start! }

    it "marks the execution as success" do
      execution = handler.finish!
      expect(execution.status).to eq("success")
      expect(execution.finished_at).to be_present
    end

    it "persists execution data" do
      state.store_context("test", [{ "json" => { "key" => "value" } }])
      execution = handler.finish!
      expect(execution.execution_data).to be_present
    end
  end

  describe "#fail!" do
    before { state.start! }

    it "marks the execution as error with the error message" do
      execution = handler.fail!(RuntimeError.new("something broke"))
      expect(execution.status).to eq("error")
      expect(execution.error).to eq("something broke")
      expect(execution.finished_at).to be_present
    end

    it "truncates long error messages" do
      long_message = "x" * 2000
      execution = handler.fail!(RuntimeError.new(long_message))
      expect(execution.error.length).to be <= 1000
    end
  end

  describe "#wait!" do
    before { state.start! }

    it "raises when no waiting step is set" do
      error = DiscourseWorkflows::WaitForResume.new(type: :form, message: "waiting for form")
      expect { handler.wait!(error) }.not_to raise_error
      expect(state.execution.status).to eq("error")
    end

    it "sets the step status to waiting when step and node are present" do
      step =
        DiscourseWorkflows::Executor::Step.new(
          node_id: "1",
          node_name: "test",
          node_type: "action:code",
          position: 0,
          input: [],
        )
      node = instance_double(DiscourseWorkflows::WorkflowSnapshot::SnapshotNode)
      state.mark_wait(node: node, step: step)

      wait_handler = instance_double(DiscourseWorkflows::Executor::WaitHandlers::Base)
      handler_class = class_double(DiscourseWorkflows::Executor::WaitHandlers::Base)
      allow(handler_class).to receive(:new).and_return(wait_handler)
      allow(DiscourseWorkflows::Executor::WaitHandlers).to receive(:for).and_return(handler_class)
      allow(wait_handler).to receive(:pause!)

      error = DiscourseWorkflows::WaitForResume.new(type: :form, message: "waiting for form")
      handler.wait!(error)

      expect(step).to be_waiting
    end
  end

  describe "#create_terminal" do
    it "creates a skipped execution" do
      execution = handler.create_terminal(:skipped)
      expect(execution).to have_attributes(
        workflow: workflow,
        trigger_node_id: "trigger-1",
        status: "skipped",
        trigger_data: trigger_data,
        started_at: be_present,
        finished_at: be_present,
      )
    end

    it "creates a rate_limited execution" do
      execution = handler.create_terminal(:rate_limited)
      expect(execution.status).to eq("rate_limited")
    end
  end
end
