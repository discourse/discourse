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

    let(:params) do
      { workflow_id: workflow.id, trigger_node_id: "trigger-1", post_id: post_record.id }
    end
    let(:dependencies) { { guardian: Guardian.new(member) } }

    before { DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow) }

    context "when contract is invalid" do
      let(:params) { { trigger_node_id: nil, post_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when workflow is not found" do
      let(:params) do
        { workflow_id: workflow.id, trigger_node_id: "nonexistent", post_id: post_record.id }
      end

      it { is_expected.to fail_to_find_a_model(:published_trigger) }
    end

    context "when workflow is unpublished" do
      before { unpublish_workflow!(workflow) }

      it { is_expected.to fail_to_find_a_model(:published_trigger) }
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
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      end

      before { DiscourseWorkflows::WorkflowDependencyIndexer.call(other_workflow) }

      it "enqueues each specifically requested workflow" do
        service_results = []

        expect do
          [workflow, other_workflow].each do |requested_workflow|
            service_results << described_class.call(
              params: params.merge(workflow_id: requested_workflow.id),
              **dependencies,
            )
          end
        end.to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }.by(2)

        service_results.each { |service_result| expect(service_result).to run_successfully }
        expect(
          Jobs::DiscourseWorkflows::ExecuteWorkflow
            .jobs
            .last(2)
            .map { |job| job["args"].first["workflow_id"] },
        ).to eq([workflow.id, other_workflow.id])
      end

      it "fails to find a trigger when a legacy request is ambiguous" do
        legacy_params = params.except(:workflow_id)
        legacy_result = nil

        expect do
          legacy_result = described_class.call(params: legacy_params, **dependencies)
        end.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
        expect(legacy_result).to fail_to_find_a_model(:published_trigger)
      end
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
      let(:params) { { workflow_id: workflow.id, trigger_node_id: "trigger-1", post_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:post) }
    end

    context "when the user cannot see the post" do
      fab!(:private_post) do
        category = Fabricate(:private_category, group: Fabricate(:group))
        Fabricate(:post, topic: Fabricate(:topic, category: category))
      end

      let(:params) do
        { workflow_id: workflow.id, trigger_node_id: "trigger-1", post_id: private_post.id }
      end

      it { is_expected.to fail_a_policy(:can_see_post) }
    end

    context "when the configured post number does not match" do
      before do
        update_workflow_node(workflow, "trigger-1") do |node|
          node.merge(
            "parameters" => {
              "label" => "Run workflow",
              "icon" => "bolt",
              "group_ids" => [group.id],
              "post_number" => post_record.post_number + 1,
            },
          )
        end
        publish_workflow!(workflow)
      end

      it "fails the post-number policy without enqueuing a workflow" do
        expect { result }.not_to change { Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.size }
        expect(result).to fail_a_policy(:can_trigger_for_post)
      end
    end

    context "when the post number is omitted" do
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

    context "when a legacy request omits the workflow id" do
      let(:params) { { trigger_node_id: "trigger-1", post_id: post_record.id } }

      it { is_expected.to run_successfully }
    end

    context "when the configured post number matches" do
      before do
        update_workflow_node(workflow, "trigger-1") do |node|
          node.merge(
            "parameters" => {
              "label" => "Run workflow",
              "icon" => "bolt",
              "group_ids" => [group.id],
              "post_number" => post_record.post_number.to_s,
            },
          )
        end
        publish_workflow!(workflow)
      end

      it { is_expected.to run_successfully }
    end
  end
end
