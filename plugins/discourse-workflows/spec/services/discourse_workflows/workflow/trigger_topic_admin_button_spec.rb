# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::TriggerTopicAdminButton do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:trigger_node_id) }
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:topic)
    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:topic_admin_button",
                 configuration: {
                   "label" => "Run workflow",
                   "icon" => "gear",
                 }
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    end

    let(:params) { { trigger_node_id: "trigger-1", topic_id: topic.id } }
    let(:dependencies) { { guardian: Guardian.new(admin) } }

    before { DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow) }

    context "when contract is invalid" do
      let(:params) { { trigger_node_id: nil, topic_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user is not an admin" do
      fab!(:acting_user, :user)
      let(:dependencies) { { guardian: Guardian.new(acting_user) } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when workflow is not found" do
      let(:params) { { trigger_node_id: "nonexistent", topic_id: topic.id } }

      it { is_expected.to fail_to_find_a_model(:published_trigger) }
    end

    context "when workflow is unpublished" do
      before { unpublish_workflow!(workflow) }

      it { is_expected.to fail_to_find_a_model(:published_trigger) }
    end

    context "when topic does not exist" do
      let(:params) { { trigger_node_id: "trigger-1", topic_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "enqueues an ExecuteWorkflow job" do
        result
        job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
        expect(job["args"].first).to include(
          "trigger_node_id" => "trigger-1",
          "workflow_id" => workflow.id,
          "workflow_version_id" => workflow.active_version_id,
          "user_id" => admin.id,
        )
        expect(job["args"].first["trigger_data"]["topic"]).to include(
          "id" => topic.id,
          "title" => topic.title,
        )
        expect(
          job["args"].first["trigger_data"]["topic"]["posters"].map { |poster| poster["user_id"] },
        ).to include(topic.user_id)
      end
    end
  end
end
