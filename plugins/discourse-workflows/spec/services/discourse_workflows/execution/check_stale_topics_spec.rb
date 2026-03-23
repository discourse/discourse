# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::CheckStaleTopics do
  describe ".call" do
    subject(:result) { described_class.call }

    fab!(:admin)
    fab!(:topic) { Fabricate(:topic, created_at: 48.hours.ago, last_posted_at: 48.hours.ago) }
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, enabled: true, created_by: admin) }
    fab!(:trigger_node) do
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:stale_topic",
        name: "Stale Topic",
        configuration: {
          "hours" => 24,
        },
      )
    end

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when plugin is disabled" do
      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when stale topics exist" do
      it "enqueues execution" do
        result

        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
        job_args = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.first["args"].first
        expect(job_args["trigger_node_id"]).to eq(trigger_node.id)
        expect(job_args["trigger_data"]["topic_id"]).to eq(topic.id)
      end

      it "stores triggered topic IDs in node static_data" do
        result

        trigger_node.reload
        expect(trigger_node.static_data["triggered_topic_ids"]).to include(topic.id)
      end
    end

    context "when topic is newer than threshold" do
      before { topic.update!(created_at: 12.hours.ago, last_posted_at: 12.hours.ago) }

      it "does not enqueue" do
        result
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
      end
    end

    context "when topic was already triggered" do
      it "does not fire twice" do
        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear
        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
      end
    end

    context "when topic is removed from static_data" do
      it "fires again" do
        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

        trigger_node.update!(static_data: {})
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear

        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
      end
    end

    context "when topic is closed" do
      before { topic.update!(closed: true) }

      it "does not enqueue" do
        result
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
      end
    end

    context "when topic is archived" do
      before { topic.update!(archived: true) }

      it "does not enqueue" do
        result
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
      end
    end

    context "when workflow is disabled" do
      before { workflow.update!(enabled: false) }

      it "does not enqueue" do
        result
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
      end
    end

    context "when topic has recent replies" do
      before { topic.update!(created_at: 72.hours.ago, last_posted_at: 2.hours.ago) }

      it "does not enqueue" do
        result
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
      end
    end
  end
end
