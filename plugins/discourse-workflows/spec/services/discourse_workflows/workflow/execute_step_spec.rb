# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::ExecuteStep do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:node_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:post_created"
          g.node "set-1",
                 "action:set_fields",
                 configuration: {
                   "mode" => "raw",
                   "include_other_fields" => true,
                   "json_output" => '{"a": 1}',
                 }
          g.chain "trigger-1", "set-1"
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    end

    let(:params) { { workflow_id: workflow.id, node_id: "set-1" } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { super().merge(node_id: nil) }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when workflow does not exist" do
      let(:params) { super().merge(workflow_id: -1) }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when node does not exist" do
      let(:params) { super().merge(node_id: "nonexistent") }

      it { is_expected.to fail_to_find_a_model(:step_node) }
    end

    context "when node is a trigger" do
      let(:params) { super().merge(node_id: "trigger-1") }

      it { is_expected.to fail_a_policy(:step_node_executable) }
    end

    context "when node waits for a resume" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:post_created"
            g.node "wait-1",
                   "flow:wait",
                   configuration: {
                     "resume" => "time_interval",
                     "wait_amount" => 1,
                     "wait_unit" => "hours",
                   }
            g.chain "trigger-1", "wait-1"
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      end

      let(:params) { super().merge(node_id: "wait-1") }

      it { is_expected.to fail_a_policy(:step_node_not_waiting) }
    end

    context "when the node has a connected input but no data source" do
      it { is_expected.to fail_a_policy(:step_data_reachable) }
    end

    context "when an un-cached upstream node waits for a resume" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:post_created"
            g.node "wait-1",
                   "flow:wait",
                   configuration: {
                     "resume" => "time_interval",
                     "wait_amount" => 1,
                     "wait_unit" => "hours",
                   }
            g.node "set-1",
                   "action:set_fields",
                   configuration: {
                     "mode" => "raw",
                     "include_other_fields" => true,
                     "json_output" => '{"a": 1}',
                   }
            g.chain "trigger-1", "wait-1", "set-1"
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      end

      before do
        workflow.update_node_pin_data!("Trigger-1", [{ "json" => { "post" => { "id" => 1 } } }])
      end

      it { is_expected.to fail_a_policy(:execution_path_not_waiting) }
    end

    context "when the upstream trigger can produce manual data" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1",
                   "trigger:schedule",
                   configuration: {
                     rule: {
                       interval: [{ field: "minutes", minutesInterval: 5 }],
                     },
                   }
            g.node "set-1",
                   "action:set_fields",
                   configuration: {
                     "mode" => "raw",
                     "include_other_fields" => true,
                     "json_output" => '{"a": 1}',
                   }
            g.chain "trigger-1", "set-1"
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      end

      it "computes fresh trigger data for the run" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)

        expect(result).to run_successfully
        expect(result[:execution].trigger_data).to include(
          "timestamp" => "2026-03-18T09:00:00.000Z",
          "hour" => "09",
        )
      end
    end

    context "when the upstream trigger has pinned data" do
      before do
        workflow.update_node_pin_data!(
          "Trigger-1",
          [{ "json" => { "post" => { "id" => 42, "raw" => "pinned body" } } }],
        )
      end

      it "creates a pending step execution and enqueues the job" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1).and change {
                Jobs::DiscourseWorkflows::ExecuteManualWorkflow.jobs.size
              }.by(1)

        expect(result).to run_successfully
        execution = result[:execution]
        expect(execution).to have_attributes(
          status: "pending",
          execution_mode: "manual",
          trigger_node_id: "set-1",
        )
        expect(execution.execution_data.run_data).to eq({})

        job_args = Jobs::DiscourseWorkflows::ExecuteManualWorkflow.jobs.last["args"].first
        expect(job_args).to include(
          "execution_id" => execution.id,
          "user_id" => admin.id,
          "step_node_id" => "set-1",
        )
      end
    end

    context "when a previous successful execution provides run data" do
      let!(:source_execution) do
        DiscourseWorkflows::Executor.new(
          workflow,
          "trigger-1",
          { "seed" => true },
          DiscourseWorkflows::Executor::ExecutionOptions.new(
            user: admin,
            execution_mode: :manual,
            draft_execution: true,
          ),
        ).run
      end

      it "seeds the new execution with the source execution's run data" do
        expect(result).to run_successfully

        execution = result[:execution]
        expect(execution.execution_data.run_data).to eq(
          source_execution.reload.execution_data.run_data,
        )
        expect(execution.trigger_data).to eq(source_execution.trigger_data)
      end
    end

    context "when a merge node has data for only one of its inputs" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:post_created"
            g.node "set-a",
                   "action:set_fields",
                   name: "A",
                   configuration: {
                     "mode" => "raw",
                     "include_other_fields" => true,
                     "json_output" => '{"a": 1}',
                   }
            g.node "set-b",
                   "action:set_fields",
                   name: "B",
                   configuration: {
                     "mode" => "raw",
                     "include_other_fields" => true,
                     "json_output" => '{"b": 2}',
                   }
            g.node "merge-1", "flow:merge", name: "Merge", configuration: { "mode" => "append" }
            g.chain "trigger-1", "set-a"
            g.chain "trigger-1", "set-b"
            g.connect "set-a", "merge-1", input: "input_1"
            g.connect "set-b", "merge-1", input: "input_2"
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      end

      let(:params) { super().merge(node_id: "merge-1") }

      before { workflow.update_node_pin_data!("A", [{ "json" => { "pinned" => true } }]) }

      it { is_expected.to run_successfully }
    end

    context "when the node has no inbound connections" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:post_created"
            g.node "solo-1",
                   "action:set_fields",
                   configuration: {
                     "mode" => "raw",
                     "include_other_fields" => true,
                     "json_output" => '{"solo": true}',
                   }
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      end

      let(:params) { super().merge(node_id: "solo-1") }

      it { is_expected.to run_successfully }
    end
  end
end
