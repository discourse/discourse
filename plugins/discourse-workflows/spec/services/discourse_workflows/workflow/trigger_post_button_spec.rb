# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::TriggerPostButton do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:trigger_node_id) }
    it { is_expected.to validate_presence_of(:post_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:group)
    fab!(:acting_user) { Fabricate(:user).tap { |user| group.add(user) } }
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
      Fabricate(:discourse_workflows_workflow, published: true, **graph)
    end

    let(:params) do
      { workflow_id: workflow.id, trigger_node_id: "trigger-1", post_id: post_record.id }
    end
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when contract is invalid" do
      let(:params) { { trigger_node_id: nil, post_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when workflow is not found" do
      let(:params) { super().merge(trigger_node_id: "nonexistent") }

      it { is_expected.to fail_to_find_a_model(:published_trigger) }
    end

    context "when workflow is unpublished" do
      before { unpublish_workflow!(workflow) }

      it { is_expected.to fail_to_find_a_model(:published_trigger) }
    end

    context "when a legacy request omits the workflow id" do
      let(:params) { super().except(:workflow_id) }

      it { is_expected.to run_successfully }
    end

    context "when published workflows share a trigger node id" do
      fab!(:other_workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1",
                   "trigger:post_button",
                   configuration: {
                     "label" => "Run other workflow",
                     "group_ids" => [group.id],
                   }
          end
        Fabricate(:discourse_workflows_workflow, published: true, **graph)
      end

      let(:params) { super().merge(workflow_id: other_workflow.id) }

      it "enqueues the requested workflow" do
        result

        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first).to include(
          "workflow_id" => other_workflow.id,
        )
      end

      context "when a legacy request omits the workflow id" do
        let(:params) { super().except(:workflow_id) }

        it { is_expected.to fail_to_find_a_model(:published_trigger) }
      end
    end

    context "when user is in none of the configured groups" do
      fab!(:acting_user, :user)

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
      let(:params) { super().merge(post_id: -1) }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when the user cannot see the post" do
      fab!(:post_record) do
        category = Fabricate(:private_category, group: Fabricate(:group))
        Fabricate(:post, topic: Fabricate(:topic, category:))
      end

      it { is_expected.to fail_a_policy(:can_see_post) }
    end

    context "when a moderator triggers the first post of a deleted topic" do
      fab!(:acting_user) { Fabricate(:moderator).tap { |user| group.add(user) } }

      before { PostDestroyer.new(acting_user, post_record).destroy }

      it { is_expected.to run_successfully }
    end

    context "when a group member triggers a deleted reply" do
      fab!(:post_record) { Fabricate(:post, topic: Fabricate(:topic_with_op)) }

      before { post_record.trash! }

      it { is_expected.to fail_a_policy(:can_see_post) }
    end

    context "when the configured post number does not match" do
      before do
        update_workflow_node(workflow, "trigger-1") do |node|
          node.deep_merge("parameters" => { "post_number" => post_record.post_number + 1 })
        end
        publish_workflow!(workflow)
      end

      it { is_expected.to fail_a_policy(:can_trigger_for_post) }
    end

    context "when the configured post number matches" do
      before do
        update_workflow_node(workflow, "trigger-1") do |node|
          node.deep_merge("parameters" => { "post_number" => post_record.post_number.to_s })
        end
        publish_workflow!(workflow)
      end

      it { is_expected.to run_successfully }
    end

    context "when everything is valid" do
      it "enqueues an ExecuteWorkflow job acting as the clicking user" do
        result

        expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.last["args"].first).to include(
          "trigger_node_id" => "trigger-1",
          "workflow_id" => workflow.id,
          "workflow_version_id" => workflow.active_version_id,
          "user_id" => acting_user.id,
          "trigger_data" => a_hash_including("post" => a_hash_including("id" => post_record.id)),
        )
      end
    end
  end
end
