# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::TriggerTopicAdminButton do
  describe ".call" do
    subject(:result) { described_class.call(params:, guardian:) }

    fab!(:admin)
    fab!(:user)
    fab!(:topic)
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true) }
    fab!(:trigger_node) do
      Fabricate(
        :discourse_workflows_node,
        workflow: workflow,
        type: "trigger:topic_admin_button",
        name: "Topic Admin Button",
        configuration: {
          "label" => "Run workflow",
          "icon" => "gear",
        },
      )
    end

    let(:guardian) { Guardian.new(admin) }
    let(:params) { { trigger_node_id: trigger_node.id, topic_id: topic.id } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when trigger node does not exist" do
      let(:params) { super().merge(trigger_node_id: -1) }

      it { is_expected.to fail_to_find_a_model(:trigger_node) }
    end

    context "when workflow is disabled" do
      before { workflow.update!(enabled: false) }

      it { is_expected.to fail_to_find_a_model(:trigger_node) }
    end

    context "when topic does not exist" do
      let(:params) { super().merge(topic_id: -1) }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when user is not an admin" do
      let(:guardian) { Guardian.new(user) }

      it { is_expected.to fail_a_policy(:allowed_user) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "enqueues an ExecuteWorkflow job" do
        result
        job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
        expect(job["args"].first).to include("trigger_node_id" => trigger_node.id)
        expect(job["args"].first["trigger_data"]).to include(
          "topic_id" => topic.id,
          "topic_title" => topic.title,
          "user_id" => topic.user_id,
        )
      end
    end
  end
end
