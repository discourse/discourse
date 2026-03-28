# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::CheckSchedules do
  describe ".call" do
    subject(:result) { described_class.call }

    fab!(:user)

    before { SiteSetting.discourse_workflows_enabled = true }

    def create_schedule_workflow(cron:)
      workflow = Fabricate(:discourse_workflows_workflow, enabled: true, created_by: user)
      node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:schedule",
          configuration: {
            "cron" => cron,
          },
        )
      [workflow, node]
    end

    context "when plugin is disabled" do
      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when cron matches current time" do
      it "enqueues workflow execution" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        _workflow, node = create_schedule_workflow(cron: "0 9 * * *")

        expect { result }.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(1)

        job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
        expect(job["args"].first["trigger_node_id"]).to eq(node.id)
      end
    end

    context "when cron does not match" do
      it "does not enqueue" do
        freeze_time Time.utc(2026, 3, 18, 10, 0)
        create_schedule_workflow(cron: "0 9 * * *")

        expect { result }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
      end
    end

    context "when already triggered in the same minute" do
      it "does not fire twice" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        _workflow, _node = create_schedule_workflow(cron: "0 9 * * *")

        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
      end
    end

    context "when next matching minute arrives" do
      it "fires again" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        _workflow, _node = create_schedule_workflow(cron: "0 * * * *")

        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

        freeze_time Time.utc(2026, 3, 18, 10, 0)
        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(2)
      end
    end

    context "when workflow is disabled" do
      it "does not enqueue" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        workflow, _node = create_schedule_workflow(cron: "0 9 * * *")
        workflow.update!(enabled: false)

        expect { result }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
      end
    end

    context "when cron expression is invalid" do
      it "skips the node" do
        freeze_time Time.utc(2026, 3, 18, 9, 0)
        workflow = Fabricate(:discourse_workflows_workflow, enabled: true, created_by: user)
        node =
          Fabricate.build(
            :discourse_workflows_node,
            workflow: workflow,
            type: "trigger:schedule",
            configuration: {
              "cron" => "invalid",
            },
          )
        node.save!(validate: false)

        expect { result }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
      end
    end
  end
end
