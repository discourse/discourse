# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::UpdatePinData do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_presence_of(:node_name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:post_created"
          g.node "filter-1", "action:filter"
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    end

    let(:items) { [{ "json" => { "post" => { "id" => 7 } } }] }
    let(:params) { { workflow_id: workflow.id, node_name: "Trigger-1", items: items } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when the workflow does not exist" do
      let(:params) { super().merge(workflow_id: -1) }

      it { is_expected.to fail_to_find_a_model(:workflow) }
    end

    context "when the node does not exist" do
      let(:params) { super().merge(node_name: "missing") }

      it { is_expected.to fail_to_find_a_model(:node) }
    end

    context "when the node has more than one primary output" do
      fab!(:workflow) do
        graph =
          build_workflow_graph do |g|
            g.node "trigger-1", "trigger:manual"
            g.node "if-1", "action:if"
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
      end

      let(:params) { { workflow_id: workflow.id, node_name: "If-1", items: items } }

      it { is_expected.to fail_a_policy(:node_supports_pinning) }
    end

    context "when the pinned items exceed the size cap" do
      before { SiteSetting.discourse_workflows_max_pin_data_bytes = 32 }

      let(:items) { [{ "json" => { "blob" => "x" * 5000 } }] }

      it { is_expected.to fail_a_policy(:within_size_cap) }
    end

    context "when pinning valid items" do
      it { is_expected.to run_successfully }

      it "persists the pinned data on the workflow" do
        result
        expect(workflow.reload.pin_data).to include(
          "Trigger-1" => [hash_including("json" => hash_including("post"))],
        )
      end

      it "strips unsupported top-level item payloads" do
        items.first["binary"] = { "file" => { "fileName" => "x.png" } }
        result
        pinned = workflow.reload.pin_data["Trigger-1"].first
        expect(pinned).not_to have_key("binary")
      end
    end

    context "when unpinning" do
      before { workflow.update_node_pin_data!("Trigger-1", [{ "json" => { "x" => 1 } }]) }

      let(:params) { { workflow_id: workflow.id, node_name: "Trigger-1" } }

      it { is_expected.to run_successfully }

      it "removes the entry for that node from pin data" do
        result
        expect(workflow.reload.pin_data).not_to have_key("Trigger-1")
      end
    end
  end
end
