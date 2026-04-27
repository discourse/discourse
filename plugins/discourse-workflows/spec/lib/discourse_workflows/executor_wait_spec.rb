# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)

  describe "pause on wait request" do
    it "pauses execution and stores the waiting node id when a node signals wait" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "wait-1", "flow:wait", configuration: { "resume" => "webhook" }
          g.node "after-1",
                 "action:set_fields",
                 name: "After",
                 configuration: {
                   "mode" => "json",
                   "include_input" => true,
                   "json" => '{"done": "true"}',
                 }
          g.chain "trigger-1", "wait-1", "after-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(
          status: "waiting",
          waiting_node_id: "wait-1",
          finished_at: nil,
        )
        expect(execution.waiting_until).to eq(
          described_class::MAX_WAIT_DURATION_SECONDS.seconds.from_now,
        )

        waiting_step = execution.execution_data.find_step(node_id: "wait-1")
        expect(waiting_step["status"]).to eq("waiting")

        expect(execution.execution_data.context_data).not_to have_key("After")
      end
    end

    it "applies the default wait ceiling to form waits" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "form-1",
                 "action:form",
                 configuration: {
                   "form_title" => "Approval",
                   "form_fields" => [{ "field_label" => "Reason", "field_type" => "text" }],
                 }
          g.chain "trigger-1", "form-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      allow(MessageBus).to receive(:publish)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(status: "waiting", waiting_node_id: "form-1")
        expect(execution.waiting_until).to eq(
          described_class::MAX_WAIT_DURATION_SECONDS.seconds.from_now,
        )
      end
    end

    it "caps explicit timer waits at the executor ceiling" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "wait-1",
                 "flow:wait",
                 configuration: {
                   "resume" => "time_interval",
                   "wait_amount" => 60,
                   "wait_unit" => "days",
                 }
          g.chain "trigger-1", "wait-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(status: "waiting", waiting_node_id: "wait-1")
        expect(execution.waiting_until).to eq(
          described_class::MAX_WAIT_DURATION_SECONDS.seconds.from_now,
        )
      end
    end

    it "caps explicit webhook waits at the executor ceiling" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "wait-1",
                 "flow:wait",
                 configuration: {
                   "resume" => "webhook",
                   "limit_wait_time" => true,
                   "timeout_amount" => 60,
                   "timeout_unit" => "days",
                 }
          g.chain "trigger-1", "wait-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(status: "waiting", waiting_node_id: "wait-1")
        expect(execution.waiting_until).to eq(
          described_class::MAX_WAIT_DURATION_SECONDS.seconds.from_now,
        )
      end
    end
  end

  describe ".resume" do
    fab!(:completed_execution) { Fabricate(:discourse_workflows_execution, status: :success) }

    it "resumes a waiting execution and continues to downstream nodes" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "wait-1", "flow:wait", configuration: { "resume" => "webhook" }
          g.node "after-1",
                 "action:set_fields",
                 name: "After",
                 configuration: {
                   "mode" => "json",
                   "include_input" => true,
                   "json" => '{"done": "true"}',
                 }
          g.chain "trigger-1", "wait-1", "after-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run
      expect(execution.status).to eq("waiting")

      response_items = [{ "json" => { "approved" => true } }]
      claimed = DiscourseWorkflows::Execution.claim_for_resume(id: execution.id)
      resumed = DiscourseWorkflows::Executor.resume(claimed, response_items)

      expect(resumed).to have_attributes(
        status: "success",
        finished_at: be_present,
        waiting_node_id: nil,
      )

      after_output = resumed.execution_data.context_data["After"]
      expect(after_output).to be_an(Array)
      expect(after_output.first["json"]).to include("approved" => true, "done" => "true")
    end

    it "raises when the execution has not been claimed for resume" do
      response_items = [{ "json" => { "approved" => true } }]

      expect {
        DiscourseWorkflows::Executor.resume(completed_execution, response_items)
      }.to raise_error(ArgumentError, /Cannot resume execution/)
    end
  end
end
