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
                   "mode" => "raw",
                   "include_other_fields" => true,
                   "json_output" => '{"done": "true"}',
                 }
          g.chain "trigger-1", "wait-1", "after-1"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(
          status: "waiting",
          waiting_node_id: "wait-1",
          finished_at: nil,
        )
        expect(execution.waiting_until).to eq_time(
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
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      allow(MessageBus).to receive(:publish)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(status: "waiting", waiting_node_id: "form-1")
        expect(execution.waiting_until).to eq_time(
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
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(status: "waiting", waiting_node_id: "wait-1")
        expect(execution.waiting_until).to eq_time(
          described_class::MAX_WAIT_DURATION_SECONDS.seconds.from_now,
        )
      end
    end

    it "persists explicit timer waits" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "wait-1",
                 "flow:wait",
                 configuration: {
                   "resume" => "time_interval",
                   "wait_amount" => 2,
                   "wait_unit" => "hours",
                 }
          g.chain "trigger-1", "wait-1"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(status: "waiting", waiting_node_id: "wait-1")
        expect(execution.waiting_until).to eq_time(2.hours.from_now)
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
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(status: "waiting", waiting_node_id: "wait-1")
        expect(execution.waiting_until).to eq_time(
          described_class::MAX_WAIT_DURATION_SECONDS.seconds.from_now,
        )
      end
    end

    it "persists bounded webhook waits" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "wait-1",
                 "flow:wait",
                 configuration: {
                   "resume" => "webhook",
                   "limit_wait_time" => true,
                   "timeout_amount" => 3,
                   "timeout_unit" => "hours",
                 }
          g.chain "trigger-1", "wait-1"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      freeze_time do
        execution = described_class.new(workflow, "trigger-1", {}).run

        expect(execution).to have_attributes(status: "waiting", waiting_node_id: "wait-1")
        expect(execution.waiting_until).to eq_time(3.hours.from_now)
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
                   "mode" => "raw",
                   "include_other_fields" => true,
                   "json_output" => '{"done": "true"}',
                 }
          g.chain "trigger-1", "wait-1", "after-1"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run
      expect(execution.status).to eq("waiting")

      response_items = [{ "json" => { "approved" => true } }]
      claimed = DiscourseWorkflows::Execution.claim_for_resume(execution)
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

    it "preserves pending merge inputs across a wait resume" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "list-users",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "users"}',
                 }
          g.node "wait-1", "flow:wait", configuration: { "resume" => "webhook" }
          g.node "list-groups",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "groups"}',
                 }
          g.node "merge-1", "flow:merge", name: "Merge branches"
          g.connect "trigger-1", "list-users"
          g.connect "trigger-1", "wait-1"
          g.connect "wait-1", "list-groups"
          g.connect "list-users", "merge-1", input: "input_1"
          g.connect "list-groups", "merge-1", input: "input_2"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run
      expect(execution.status).to eq("waiting")

      claimed = DiscourseWorkflows::Execution.claim_for_resume(execution.reload)
      resumed = DiscourseWorkflows::Executor.resume(claimed, [{ "json" => { "resumed" => true } }])

      expect(resumed.status).to eq("success")
      merge_run = resumed.execution_data.run_data["Merge branches"].first
      expect(merge_run["inputs"].map { |input| input["item_count"] }).to eq([1, 1])

      merge_output = resumed.execution_data.context_data["Merge branches"]
      expect(merge_output.map { |item| item["json"]["source"] }).to contain_exactly(
        "users",
        "groups",
      )
    end

    it "preserves queued sibling branches across a wait resume" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "wait-1", "flow:wait", configuration: { "resume" => "webhook" }
          g.node "list-users",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "users"}',
                 }
          g.node "list-groups",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "groups"}',
                 }
          g.node "merge-1", "flow:merge", name: "Merge branches"
          g.connect "trigger-1", "wait-1"
          g.connect "trigger-1", "list-users"
          g.connect "wait-1", "list-groups"
          g.connect "list-users", "merge-1", input: "input_1"
          g.connect "list-groups", "merge-1", input: "input_2"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run
      expect(execution.status).to eq("waiting")

      claimed = DiscourseWorkflows::Execution.claim_for_resume(execution.reload)
      resumed = DiscourseWorkflows::Executor.resume(claimed, [{ "json" => { "resumed" => true } }])

      merge_output = resumed.execution_data.context_data["Merge branches"]
      expect(merge_output.map { |item| item["json"]["source"] }).to contain_exactly(
        "users",
        "groups",
      )
    end

    it "preserves queued merge nodes across a wait resume" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "list-users",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "users"}',
                 }
          g.node "list-groups",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => false,
                   "json_output" => '{"source": "groups"}',
                 }
          g.node "wait-1", "flow:wait", configuration: { "resume" => "webhook" }
          g.node "merge-1", "flow:merge", name: "Merge branches"
          g.connect "trigger-1", "list-users"
          g.connect "trigger-1", "list-groups"
          g.connect "trigger-1", "wait-1"
          g.connect "list-users", "merge-1", input: "input_1"
          g.connect "list-groups", "merge-1", input: "input_2"
        end
      workflow =
        Fabricate(:discourse_workflows_workflow, created_by: user, published: true, **graph)

      execution = described_class.new(workflow, "trigger-1", {}).run
      expect(execution.status).to eq("waiting")

      claimed = DiscourseWorkflows::Execution.claim_for_resume(execution.reload)
      resumed = DiscourseWorkflows::Executor.resume(claimed, [{ "json" => { "resumed" => true } }])

      merge_output = resumed.execution_data.context_data["Merge branches"]
      expect(merge_output.map { |item| item["json"]["source"] }).to contain_exactly(
        "users",
        "groups",
      )
    end

    it "raises when the execution has not been claimed for resume" do
      response_items = [{ "json" => { "approved" => true } }]

      expect {
        DiscourseWorkflows::Executor.resume(completed_execution, response_items)
      }.to raise_error(ArgumentError, /Cannot resume execution/)
    end
  end
end
