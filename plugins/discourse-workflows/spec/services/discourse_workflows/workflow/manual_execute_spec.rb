# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::ManualExecute do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:trigger_node_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:manual" }
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    end

    let(:params) { { workflow_id: workflow.id, trigger_node_id: "trigger-1" } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { super().merge(trigger_node_id: nil) }

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

    context "when trigger node does not exist" do
      let(:params) { super().merge(trigger_node_id: "nonexistent") }

      it { is_expected.to fail_to_find_a_model(:trigger_node) }
    end

    context "when everything is valid" do
      it "creates a pending manual execution and enqueues a job" do
        expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1).and change {
                Jobs::DiscourseWorkflows::ExecuteManualWorkflow.jobs.size
              }.by(1)

        expect(result).to run_successfully
        execution = result[:execution]
        job_args = Jobs::DiscourseWorkflows::ExecuteManualWorkflow.jobs.last["args"].first
        expect(execution).to have_attributes(status: "pending", execution_mode: "manual")
        expect(execution.started_at).to be_nil
        expect(
          execution.execution_data.workflow_data["nodes"].map { |node| node["id"] },
        ).to contain_exactly("trigger-1")
        expect(job_args).to include("execution_id" => execution.id, "user_id" => admin.id)
      end

      context "when the trigger has pinned data" do
        fab!(:workflow) do
          graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:post_created" }
          Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
        end

        before do
          workflow.update_node_pin_data!(
            "Trigger-1",
            [{ "json" => { "post" => { "id" => 42, "raw" => "pinned body" } } }],
          )
        end

        it "stores pinned items in the execution snapshot" do
          expect(result).to run_successfully
          execution = result[:execution]
          expect(execution.trigger_data).to eq({})
          expect(execution.execution_data.workflow_data["pinData"]["Trigger-1"]).to include(
            hash_including("json" => hash_including("post" => hash_including("id" => 42))),
          )
        end
      end

      context "when the trigger is event-based without pinned data" do
        fab!(:workflow) do
          graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:post_created" }
          Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
        end

        it "runs with empty trigger data" do
          expect(result).to run_successfully
          expect(result[:execution].trigger_data).to eq({})
        end
      end

      context "when manually testing a Stale Topic trigger" do
        fab!(:workflow) do
          graph =
            build_workflow_graph do |g|
              g.node "trigger-1", "trigger:stale_topic", configuration: { "hours" => 24 }
            end
          Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
        end

        fab!(:first_stale_topic) do
          Fabricate(:topic, created_at: 48.hours.ago, last_posted_at: 48.hours.ago)
        end
        fab!(:second_stale_topic) do
          Fabricate(:topic, created_at: 48.hours.ago, last_posted_at: 48.hours.ago)
        end

        it "creates one execution carrying every stale topic as trigger data" do
          expect { result }.to change { DiscourseWorkflows::Execution.count }.by(1)

          expect(result).to run_successfully
          execution = result[:execution]
          topic_ids =
            execution.trigger_data.map { |item| item.dig("topic", "id") || item.dig(:topic, :id) }
          expect(topic_ids).to match_array([first_stale_topic.id, second_stale_topic.id])
        end
      end

      context "when manually testing a Schedule trigger" do
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
            end
          Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
        end

        it "uses the schedule trigger's manual output" do
          freeze_time Time.utc(2026, 3, 18, 9, 0)

          expect(result).to run_successfully
          expect(result[:execution].trigger_data).to include(
            "timestamp" => "2026-03-18T09:00:00.000Z",
            "hour" => "09",
            "minute" => "00",
          )
        end
      end
    end
  end
end
