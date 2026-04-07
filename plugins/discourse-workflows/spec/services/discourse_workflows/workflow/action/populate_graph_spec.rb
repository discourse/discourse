# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Action::PopulateGraph do
  fab!(:workflow, :discourse_workflows_workflow)

  describe ".call" do
    context "when nodes have invalid versions" do
      it "returns false and adds errors to the workflow" do
        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              {
                client_id: "node-1",
                type: "trigger:topic_created",
                type_version: "99.0",
                name: "Bad",
              },
            ],
            connections_data: [],
          )

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          "Unsupported version 99.0 for trigger:topic_created",
        )
      end
    end

    context "with nodes and connections" do
      let(:nodes_data) do
        [
          { client_id: "node-1", type: "trigger:topic_created", name: "Topic Created" },
          {
            client_id: "node-2",
            type: "action:topic_tags",
            name: "Topic Tags",
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

        workflow.reload
        nodes = workflow.parsed_nodes.sort_by { |n| n["position_index"] }
        expect(nodes.size).to eq(3)

        expect(nodes[0]).to include(
          "type" => "trigger:topic_created",
          "name" => "Topic Created",
          "position_index" => 0,
          "configuration" => {
          },
        )
        expect(nodes[1]).to include(
          "type" => "action:topic_tags",
          "name" => "Topic Tags",
          "position_index" => 1,
          "configuration" => {
            "tag_names" => "processed",
          },
        )
        expect(nodes[2]).to include(
          "type" => "action:send_message",
          "name" => "Send Message",
          "position_index" => 2,
          "configuration" => {
          },
        )
      end

      it "creates connections with correct attributes" do
        described_class.call(
          workflow: workflow,
          nodes_data: nodes_data,
          connections_data: connections_data,
        )

        workflow.reload
        nodes = workflow.parsed_nodes.sort_by { |n| n["position_index"] }
        connections = workflow.parsed_connections
        expect(connections.size).to eq(2)

        expect(connections[0]).to include(
          "source_node_id" => nodes[0]["id"],
          "target_node_id" => nodes[1]["id"],
          "source_output" => "yes",
        )
        expect(connections[1]).to include(
          "source_node_id" => nodes[1]["id"],
          "target_node_id" => nodes[2]["id"],
          "source_output" => "main",
        )
      end
    end

    context "when workflow has existing nodes and connections" do
      before do
        workflow.update!(
          nodes: [
            {
              "id" => "existing-1",
              "type" => "action:topic_tags",
              "type_version" => "1.0",
              "name" => "Existing Node 1",
              "position_index" => 0,
              "configuration" => {
              },
            },
            {
              "id" => "existing-2",
              "type" => "action:topic_tags",
              "type_version" => "1.0",
              "name" => "Existing Node 2",
              "position_index" => 1,
              "configuration" => {
              },
            },
          ],
          connections: [
            {
              "source_node_id" => "existing-1",
              "target_node_id" => "existing-2",
              "source_output" => "main",
            },
          ],
        )
      end

      it "removes stale nodes and creates new ones" do
        described_class.call(
          workflow: workflow,
          nodes_data: [{ client_id: "new-1", type: "trigger:topic_created", name: "New Node" }],
          connections_data: [],
        )

        workflow.reload
        expect(workflow.parsed_nodes.map { |n| n["name"] }).to eq(["New Node"])
        expect(workflow.parsed_connections).to be_empty
      end

      it "preserves the existing node's id and type_version" do
        described_class.call(
          workflow: workflow,
          nodes_data: [
            {
              client_id: "existing-1",
              type: "action:topic_tags",
              name: "Updated Name",
              configuration: {
                "tag_names" => "new",
              },
            },
          ],
          connections_data: [],
        )

        node = workflow.reload.parsed_nodes.first
        expect(node["id"]).to eq("existing-1")
        expect(node["type_version"]).to eq("1.0")
        expect(node["name"]).to eq("Updated Name")
      end

      it "cleans up static_data for removed nodes" do
        workflow.update!(
          static_data: {
            "existing-1" => {
              "key" => "value",
            },
            "existing-2" => {
              "key" => "value",
            },
          },
        )

        described_class.call(
          workflow: workflow,
          nodes_data: [
            {
              client_id: "existing-1",
              type: "action:topic_tags",
              name: "Kept Node",
              configuration: {
              },
            },
          ],
          connections_data: [],
        )

        workflow.reload
        expect(workflow.static_data).to have_key("existing-1")
        expect(workflow.static_data).not_to have_key("existing-2")
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

        workflow.reload
        expect(workflow.parsed_nodes.size).to eq(1)
        expect(workflow.parsed_connections).to be_empty
      end
    end

    context "when creating a form trigger without a uuid" do
      it "assigns a generated uuid" do
        described_class.call(
          workflow: workflow,
          nodes_data: [{ client_id: "form-1", type: "trigger:form", name: "Form" }],
          connections_data: [],
        )

        workflow.reload
        expect(workflow.parsed_nodes.first.dig("configuration", "uuid")).to be_present
      end
    end

    context "when a form trigger already has a uuid" do
      it "preserves the existing uuid" do
        described_class.call(
          workflow: workflow,
          nodes_data: [
            {
              client_id: "form-1",
              type: "trigger:form",
              name: "Form",
              configuration: {
                "uuid" => "existing-uuid",
              },
            },
          ],
          connections_data: [],
        )

        expect(workflow.reload.parsed_nodes.first.dig("configuration", "uuid")).to eq(
          "existing-uuid",
        )
      end
    end

    context "when an existing form trigger is updated" do
      before do
        workflow.update!(
          nodes: [
            {
              "id" => "form-1",
              "type" => "trigger:form",
              "type_version" => "1.0",
              "name" => "Form",
              "position_index" => 0,
              "configuration" => {
                "uuid" => "original-uuid",
              },
            },
          ],
        )
      end

      it "preserves the original uuid from existing configuration" do
        described_class.call(
          workflow: workflow,
          nodes_data: [
            {
              client_id: "form-1",
              type: "trigger:form",
              name: "Updated Form",
              configuration: {
                "some_field" => "value",
              },
            },
          ],
          connections_data: [],
        )

        node = workflow.reload.parsed_nodes.first
        expect(node.dig("configuration", "uuid")).to eq("original-uuid")
        expect(node.dig("configuration", "some_field")).to eq("value")
      end
    end
  end
end
