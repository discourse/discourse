# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Action::FindPublishedTriggers do
  describe ".call" do
    subject(:result) do
      described_class.call(
        trigger_type: "trigger:form",
        filter:
          lambda do |published_trigger|
            published_trigger.trigger_node["webhookId"] == "published-uuid"
          end,
      )
    end

    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:form", webhook_id: "published-uuid"
        end
      Fabricate(:discourse_workflows_workflow, published: true, **graph)
    end

    context "when the draft changes after publishing" do
      before do
        update_workflow_node(workflow, "trigger-1") { |node| node["webhookId"] = "draft-uuid" }
      end

      it "returns the published trigger node" do
        expect(workflow.reload.nodes.first["webhookId"]).to eq("draft-uuid")

        expect(result.size).to eq(1)
        published_trigger = result.first
        expect(published_trigger.workflow).to eq(workflow)
        expect(published_trigger.workflow_version).to eq(workflow.active_version)
        expect(published_trigger.trigger_node).to include(
          "id" => "trigger-1",
          "type" => "trigger:form",
          "webhookId" => "published-uuid",
        )
      end
    end

    context "when the workflow is unpublished" do
      before { unpublish_workflow!(workflow) }

      it { is_expected.to be_empty }
    end
  end
end
