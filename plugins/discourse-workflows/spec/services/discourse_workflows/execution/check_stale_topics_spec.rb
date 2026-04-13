# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Execution::CheckStaleTopics do
  describe ".call" do
    subject(:result) { described_class.call }

    fab!(:admin)
    fab!(:topic) { Fabricate(:topic, created_at: 48.hours.ago, last_posted_at: 48.hours.ago) }
    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:stale_topic", configuration: { "hours" => 24 }
        end
      Fabricate(:discourse_workflows_workflow, enabled: true, created_by: admin, **graph)
    end

    context "when plugin is disabled" do
      before { SiteSetting.discourse_workflows_enabled = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when no enabled stale topic trigger nodes exist" do
      before { workflow.update!(enabled: false) }

      it { is_expected.to fail_to_find_a_model(:stale_trigger_nodes) }
    end

    context "when stale topics exist" do
      it { is_expected.to run_successfully }

      it "enqueues execution" do
        result

        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
        job_args = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.first["args"].first
        expect(job_args).to include(
          "trigger_node_id" => "trigger-1",
          "workflow_id" => workflow.id,
          "trigger_data" => include("topic" => include("id" => topic.id)),
        )
      end

      it "stores triggered topic IDs in workflow static_data" do
        result

        workflow.reload
        expect(
          DiscourseWorkflows::TriggerTracking.triggered_topic_ids(workflow, "trigger-1"),
        ).to include(topic.id)
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

    context "when a previously stale topic gets activity and goes stale again" do
      it "fires again" do
        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
        workflow.reload
        expect(
          DiscourseWorkflows::TriggerTracking.triggered_topic_ids(workflow, "trigger-1"),
        ).to include(topic.id)

        topic.update!(last_posted_at: 1.hour.ago)
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear
        described_class.call
        workflow.reload
        expect(
          DiscourseWorkflows::TriggerTracking.triggered_topic_ids(workflow, "trigger-1"),
        ).not_to include(topic.id)

        topic.update!(last_posted_at: 48.hours.ago)
        Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.clear
        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
        workflow.reload
        expect(
          DiscourseWorkflows::TriggerTracking.triggered_topic_ids(workflow, "trigger-1"),
        ).to include(topic.id)
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

    context "when topic has recent replies" do
      before { topic.update!(created_at: 72.hours.ago, last_posted_at: 2.hours.ago) }

      it "does not enqueue" do
        result
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
      end
    end
  end
end
