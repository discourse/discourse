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
      Fabricate(:discourse_workflows_workflow, published: true, created_by: admin, **graph)
    end

    context "when plugin is disabled" do
      before { SiteSetting.enable_discourse_workflows = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when no published stale topic trigger nodes exist" do
      before { unpublish_workflow!(workflow) }

      it { is_expected.to fail_to_find_a_model(:stale_trigger_nodes) }
    end

    context "when stale topics exist" do
      it { is_expected.to run_successfully }

      it "enqueues one execution carrying every stale topic as an item" do
        result

        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
        job_args = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.first["args"].first
        expect(job_args).to include(
          "trigger_node_id" => "trigger-1",
          "workflow_id" => workflow.id,
          "workflow_version_id" => workflow.active_version_id,
        )
        expect(job_args["trigger_data"]).to match([include("topic" => include("id" => topic.id))])
      end
    end

    context "when topic is newer than threshold" do
      before { topic.update!(created_at: 12.hours.ago, last_posted_at: 12.hours.ago) }

      it "does not enqueue" do
        result
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
      end
    end

    context "when called repeatedly while the topic stays stale" do
      it "re-fires each run" do
        described_class.call
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)

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

    context "when topic has recent replies" do
      before { topic.update!(created_at: 72.hours.ago, last_posted_at: 2.hours.ago) }

      it "does not enqueue" do
        result
        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(0)
      end
    end

    context "when there are multiple stale topics" do
      fab!(:topic_2) { Fabricate(:topic, created_at: 48.hours.ago, last_posted_at: 48.hours.ago) }
      fab!(:topic_3) { Fabricate(:topic, created_at: 48.hours.ago, last_posted_at: 48.hours.ago) }

      it "enqueues one job carrying every topic as an item" do
        result

        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size).to eq(1)
        items = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.first["args"].first["trigger_data"]
        topic_ids = items.map { |item| item.dig("topic", "id") }
        expect(topic_ids).to match_array([topic.id, topic_2.id, topic_3.id])
      end
    end
  end
end
