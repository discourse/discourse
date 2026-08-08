# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::TriggerPostButton do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:trigger_node_id) }
    it { is_expected.to validate_presence_of(:post_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:group)
    fab!(:member) { Fabricate(:user).tap { |user| group.add(user) } }
    fab!(:post_record, :post)
    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:post_button",
                 configuration: {
                   "label" => "Run workflow",
                   "icon" => "bolt",
                   "group_ids" => [group.id],
                 }
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    end

    let(:params) { { trigger_node_id: "trigger-1", post_id: post_record.id } }
    let(:dependencies) { { guardian: Guardian.new(member) } }

    before { DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow) }

    context "when contract is invalid" do
      let(:params) { { trigger_node_id: nil, post_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when workflow is not found" do
      let(:params) { { trigger_node_id: "nonexistent", post_id: post_record.id } }

      it { is_expected.to fail_to_find_a_model(:published_trigger) }
    end

    context "when workflow is unpublished" do
      before { unpublish_workflow!(workflow) }

      it { is_expected.to fail_to_find_a_model(:published_trigger) }
    end

    context "when user is in none of the configured groups" do
      fab!(:acting_user, :user)
      let(:dependencies) { { guardian: Guardian.new(acting_user) } }

      it { is_expected.to fail_a_policy(:can_use_post_button) }
    end

    context "when the trigger has no groups configured" do
      before do
        update_workflow_node(workflow, "trigger-1") do |node|
          node.merge("parameters" => { "label" => "Run workflow" })
        end
        publish_workflow!(workflow)
      end

      it { is_expected.to fail_a_policy(:can_use_post_button) }
    end

    context "when post does not exist" do
      let(:params) { { trigger_node_id: "trigger-1", post_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when the user cannot see the post" do
      fab!(:private_post) do
        category = Fabricate(:private_category, group: Fabricate(:group))
        Fabricate(:post, topic: Fabricate(:topic, category: category))
      end

      let(:params) { { trigger_node_id: "trigger-1", post_id: private_post.id } }

      it { is_expected.to fail_a_policy(:can_see_post) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "enqueues an ExecuteWorkflow job acting as the clicking user" do
        result
        job = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last
        expect(job["args"].first).to include(
          "trigger_node_id" => "trigger-1",
          "workflow_id" => workflow.id,
          "workflow_version_id" => workflow.active_version_id,
          "user_id" => member.id,
        )
        expect(job["args"].first["trigger_data"]["post"]).to include(
          "id" => post_record.id,
          "post_number" => post_record.post_number,
        )
        expect(job["args"].first["trigger_data"]["topic"]).to include("id" => post_record.topic_id)
      end
    end
  end
end
