# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Action::PopulateGraph do
  fab!(:workflow, :discourse_workflows_workflow)

  describe ".call" do
    context "with nodes and connections" do
      let(:nodes_data) do
        [
          { client_id: "node-1", type: "trigger:topic_created", name: "Topic Created" },
          {
            client_id: "node-2",
            type: "action:append_tags",
            name: "Append Tags",
            configuration: {
              "tag_names" => "processed",
            },
          },
          { client_id: "node-3", type: "action:send_message", name: "Send Message" },
        ]
      end

      let(:connections_data) do
        [
          { source_client_id: "node-1", target_client_id: "node-2", source_output: "yes" },
          { source_client_id: "node-2", target_client_id: "node-3" },
        ]
      end

      it "creates nodes with correct attributes and position indices" do
        described_class.call(
          workflow: workflow,
          nodes_data: nodes_data,
          connections_data: connections_data,
        )

        nodes = workflow.nodes.order(:position_index)
        expect(nodes.size).to eq(3)

        expect(nodes[0]).to have_attributes(
          type: "trigger:topic_created",
          name: "Topic Created",
          position_index: 0,
          configuration: {
          },
        )
        expect(nodes[1]).to have_attributes(
          type: "action:append_tags",
          name: "Append Tags",
          position_index: 1,
          configuration: {
            "tag_names" => "processed",
          },
        )
        expect(nodes[2]).to have_attributes(
          type: "action:send_message",
          name: "Send Message",
          position_index: 2,
          configuration: {
          },
        )
      end

      it "creates connections with correct attributes" do
        described_class.call(
          workflow: workflow,
          nodes_data: nodes_data,
          connections_data: connections_data,
        )

        nodes = workflow.nodes.order(:position_index)
        connections = workflow.connections.order(:id)
        expect(connections.size).to eq(2)

        expect(connections[0]).to have_attributes(
          source_node_id: nodes[0].id,
          target_node_id: nodes[1].id,
          source_output: "yes",
        )
        expect(connections[1]).to have_attributes(
          source_node_id: nodes[1].id,
          target_node_id: nodes[2].id,
          source_output: "main",
        )
      end
    end

    context "when workflow has existing nodes and connections" do
      fab!(:existing_node) { Fabricate(:discourse_workflows_node, workflow: workflow) }
      fab!(:existing_node_2) { Fabricate(:discourse_workflows_node, workflow: workflow) }

      fab!(:existing_connection) do
        Fabricate(
          :discourse_workflows_connection,
          workflow: workflow,
          source_node: existing_node,
          target_node: existing_node_2,
        )
      end

      it "removes stale nodes and creates new ones" do
        described_class.call(
          workflow: workflow,
          nodes_data: [{ client_id: "new-1", type: "trigger:topic_created", name: "New Node" }],
          connections_data: [],
        )

        expect(workflow.reload.nodes.pluck(:name)).to eq(["New Node"])
        expect(workflow.connections).to be_empty
      end
    end

    context "with connections referencing non-existent client IDs" do
      let(:nodes_data) do
        [{ client_id: "node-1", type: "trigger:topic_created", name: "Topic Created" }]
      end

      let(:connections_data) { [{ source_client_id: "node-1", target_client_id: "missing-node" }] }

      it "skips connections with invalid references" do
        described_class.call(
          workflow: workflow,
          nodes_data: nodes_data,
          connections_data: connections_data,
        )

        expect(workflow.nodes.size).to eq(1)
        expect(workflow.connections).to be_empty
      end
    end
  end
end
