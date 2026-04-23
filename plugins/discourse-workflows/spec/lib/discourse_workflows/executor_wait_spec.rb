# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:user)

  describe "pause on wait request" do
    it "pauses execution and stores the waiting node id when a node returns WaitForResume" do
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

    context "when a node signals via exec_ctx.put_execution_to_wait" do
      let(:ctx_wait_node_class) do
        Class.new(DiscourseWorkflows::NodeType) do
          def self.identifier
            "flow:ctx_wait"
          end

          def self.name
            "DiscourseWorkflows::NodeTypes::CtxWaitTest"
          end

          def self.waits_for_resume?
            true
          end

          def self.property_schema
            {}
          end

          def execute(exec_ctx)
            exec_ctx.put_execution_to_wait(1.hour.from_now)
            [exec_ctx.input_items]
          end
        end
      end

      let(:plugin) do
        p = Plugin::Instance.new
        p.enabled_site_setting(:discourse_workflows_enabled)
        p
      end

      before do
        DiscoursePluginRegistry.register_discourse_workflows_node(ctx_wait_node_class, plugin)
        DiscourseWorkflows::Registry.reset_indexes!
      end

      after do
        DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |h|
          h[:value] == ctx_wait_node_class
        end
        DiscourseWorkflows::Registry.reset_indexes!
      end

      it "pauses the execution and records the waiting node" do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:manual"
            g.node "wait-1", "flow:ctx_wait"
            g.chain "trigger-1", "wait-1"
          end
        workflow =
          Fabricate(:discourse_workflows_workflow, created_by: user, enabled: true, **graph)

        freeze_time do
          execution = described_class.new(workflow, "trigger-1", {}).run

          expect(execution).to have_attributes(
            status: "waiting",
            waiting_node_id: "wait-1",
            waiting_until: 1.hour.from_now,
          )
        end
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
      resumed = DiscourseWorkflows::Executor.resume(execution.reload, response_items)

      expect(resumed).to have_attributes(
        status: "success",
        finished_at: be_present,
        waiting_node_id: nil,
      )

      after_output = resumed.execution_data.context_data["After"]
      expect(after_output).to be_an(Array)
      expect(after_output.first["json"]).to include("approved" => true, "done" => "true")
    end

    it "raises when attempting to resume a non-waiting execution" do
      response_items = [{ "json" => { "approved" => true } }]

      expect {
        DiscourseWorkflows::Executor.resume(completed_execution, response_items)
      }.to raise_error(ArgumentError, /Cannot resume execution/)
    end
  end
end
