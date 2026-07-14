# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Action::PopulateGraph do
  fab!(:workflow, :discourse_workflows_workflow)

  describe ".call" do
    context "when node count exceeds the maximum" do
      it "returns false and adds an error to the workflow" do
        nodes_data =
          (described_class::MAX_NODES + 1).times.map do |i|
            { id: "node-#{i}", type: "trigger:topic_created", name: "Node #{i}" }
          end

        result =
          described_class.call(workflow: workflow, nodes_data: nodes_data, connections_data: {})

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          /cannot have more than #{described_class::MAX_NODES}/,
        )
      end

      it "accepts exactly the maximum number of nodes" do
        nodes_data =
          described_class::MAX_NODES.times.map do |i|
            { id: "node-#{i}", type: "trigger:topic_created", name: "Node #{i}" }
          end

        result =
          described_class.call(workflow: workflow, nodes_data: nodes_data, connections_data: {})

        expect(result).to eq(true)
        expect(workflow.reload.nodes.size).to eq(described_class::MAX_NODES)
      end
    end

    context "when a node type exceeds its per-workflow limit" do
      it "returns false and adds an error to the workflow" do
        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "error-1", type: "trigger:error", name: "Error one" },
              { id: "error-1", type: "trigger:error", name: "Error one" },
              { id: "error-2", type: "trigger:error", name: "Error two" },
            ],
            connections_data: {
            },
          )

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          I18n.t(
            "discourse_workflows.errors.max_nodes_of_type_exceeded",
            max: 1,
            type: "trigger:error",
          ),
        )
      end
    end

    context "when a connection targets a node without input ports" do
      it "returns false and adds an error to the workflow" do
        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "manual-1", type: "trigger:manual", name: "Manual" },
              { id: "error-1", type: "trigger:error", name: "Error trigger" },
            ],
            connections_data: {
              "Manual" => {
                "main" => [[{ "node" => "Error trigger", "type" => "main", "index" => 0 }]],
              },
            },
          )

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          I18n.t("discourse_workflows.errors.node_does_not_accept_inputs", node: "Error trigger"),
        )
      end
    end

    context "when workflow calls reference other workflows" do
      it "allows a draft workflow call node without a selected target" do
        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "trigger-1", type: "trigger:manual", name: "Manual" },
              { id: "call-1", type: "action:workflow_call", name: "Call workflow", parameters: {} },
            ],
            connections_data: {
              "Manual" => {
                "main" => [[{ "node" => "Call workflow", "type" => "main", "index" => 0 }]],
              },
            },
          )

        expect(result).to eq(true)
        expect(workflow.errors).to be_empty
        expect(workflow.nodes.find { |node| node["id"] == "call-1" }["parameters"]).to eq({})
      end

      it "accepts a published callable workflow target" do
        target_graph =
          build_workflow_graph { |graph| graph.node "call-trigger", "trigger:workflow_call" }
        target =
          Fabricate(
            :discourse_workflows_workflow,
            created_by: workflow.created_by,
            published: true,
            **target_graph,
          )

        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "trigger-1", type: "trigger:manual", name: "Manual" },
              {
                id: "call-1",
                type: "action:workflow_call",
                name: "Call workflow",
                parameters: {
                  "workflow_id" => target.id,
                },
              },
            ],
            connections_data: {
              "Manual" => {
                "main" => [[{ "node" => "Call workflow", "type" => "main", "index" => 0 }]],
              },
            },
          )

        expect(result).to eq(true)
      end

      it "rejects self references and non-callable targets" do
        non_callable = Fabricate(:discourse_workflows_workflow, created_by: workflow.created_by)

        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "trigger-1", type: "trigger:manual", name: "Manual" },
              {
                id: "self-call",
                type: "action:workflow_call",
                name: "Self call",
                parameters: {
                  "workflow_id" => workflow.id,
                },
              },
              {
                id: "bad-call",
                type: "action:workflow_call",
                name: "Bad call",
                parameters: {
                  "workflow_id" => non_callable.id,
                },
              },
            ],
            connections_data: {
            },
          )

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          I18n.t("discourse_workflows.errors.workflow_call.self_reference", node: "Self call"),
          I18n.t("discourse_workflows.errors.workflow_call.target_not_callable"),
        )
      end

      it "rejects workflow call cycles" do
        cyclic_target_graph =
          build_workflow_graph do |graph|
            graph.node "call-trigger", "trigger:workflow_call"
            graph.node "call-back",
                       "action:workflow_call",
                       configuration: {
                         "workflow_id" => workflow.id,
                       }
            graph.chain "call-trigger", "call-back"
          end
        cyclic_target =
          Fabricate(
            :discourse_workflows_workflow,
            created_by: workflow.created_by,
            published: true,
            **cyclic_target_graph,
          )

        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "trigger-1", type: "trigger:workflow_call", name: "Workflow call" },
              {
                id: "cycle-call",
                type: "action:workflow_call",
                name: "Cycle call",
                parameters: {
                  "workflow_id" => cyclic_target.id,
                },
              },
            ],
            connections_data: {
              "Workflow call" => {
                "main" => [[{ "node" => "Cycle call", "type" => "main", "index" => 0 }]],
              },
            },
          )

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          I18n.t("discourse_workflows.errors.workflow_call.cycle", node: "Cycle call"),
        )
      end
    end

    context "when nodes have invalid versions" do
      it "returns false and adds errors to the workflow" do
        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "node-1", type: "trigger:topic_created", typeVersion: "99.0", name: "Bad" },
            ],
            connections_data: {
            },
          )

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          I18n.t(
            "discourse_workflows.errors.unsupported_node_version",
            version: "99.0",
            type: "trigger:topic_created",
          ),
        )
      end
    end

    context "when a node type is registered by a disabled plugin" do
      it "accepts existing unavailable nodes" do
        plugin = Plugin::Instance.new
        allow(plugin).to receive(:enabled?).and_return(false)
        node_class =
          Class.new(DiscourseWorkflows::NodeType) do
            description(name: "action:populate_disabled_plugin_test", version: "1.0")
          end

        DiscoursePluginRegistry.register_discourse_workflows_node(node_class, plugin)

        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              {
                id: "node-1",
                type: "action:populate_disabled_plugin_test",
                typeVersion: "1.0",
                name: "Unavailable node",
              },
            ],
            connections_data: {
            },
          )

        expect(result).to eq(true)
        expect(workflow.reload.nodes.first).to include(
          "type" => "action:populate_disabled_plugin_test",
          "typeVersion" => "1.0",
        )
      ensure
        DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
          entry[:value] == node_class
        end
        DiscourseWorkflows::Registry.reset_indexes!
      end
    end

    context "when a node type has multiple versions" do
      it "uses the latest version for new nodes without a submitted typeVersion" do
        v1 =
          Class.new(DiscourseWorkflows::NodeType) do
            description(name: "action:populate_versioned_test", version: "1.0")
          end
        v2 =
          Class.new(DiscourseWorkflows::NodeType) do
            description(name: "action:populate_versioned_test", version: "2.0")
          end

        DiscoursePluginRegistry.register_discourse_workflows_node(v1, Plugin::Instance.new)
        DiscoursePluginRegistry.register_discourse_workflows_node(v2, Plugin::Instance.new)
        DiscourseWorkflows::Registry.reset_indexes!

        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "node-1", type: "action:populate_versioned_test", name: "Versioned" },
            ],
            connections_data: {
            },
          )

        expect(result).to eq(true)
        expect(workflow.reload.nodes.first["typeVersion"]).to eq("2.0")
      ensure
        DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
          [v1, v2].include?(entry[:value])
        end
        DiscourseWorkflows::Registry.reset_indexes!
      end
    end

    context "with nodes and connections" do
      let(:nodes_data) do
        [
          { id: "node-1", type: "trigger:topic_created", name: "Topic Created" },
          {
            id: "node-2",
            type: "action:topic_tags",
            name: "Topic Tags",
            parameters: {
              "tag_names" => "processed",
            },
          },
          { id: "node-3", type: "action:log", name: "Log" },
        ]
      end

      let(:connections_data) do
        {
          "Topic Created" => {
            "main" => [[{ "node" => "Topic Tags", "type" => "main", "index" => 0 }]],
          },
          "Topic Tags" => {
            "main" => [[{ "node" => "Log", "type" => "main", "index" => 0 }]],
          },
        }
      end

      it "creates nodes with workflow document attributes" do
        described_class.call(
          workflow: workflow,
          nodes_data: nodes_data,
          connections_data: connections_data,
        )

        workflow.reload
        nodes = workflow.nodes
        expect(nodes.size).to eq(3)

        expect(nodes[0]).to include(
          "type" => "trigger:topic_created",
          "name" => "Topic Created",
          "parameters" => {
          },
          "credentials" => {
          },
        )
        expect(nodes[1]).to include(
          "type" => "action:topic_tags",
          "name" => "Topic Tags",
          "parameters" => {
            "tag_names" => "processed",
          },
          "credentials" => {
          },
        )
        expect(nodes[2]).to include(
          "type" => "action:log",
          "name" => "Log",
          "parameters" => {
          },
          "credentials" => {
          },
        )
        expect(nodes).not_to include(include("position_index"))
      end

      it "creates connections with correct attributes" do
        described_class.call(
          workflow: workflow,
          nodes_data: nodes_data,
          connections_data: connections_data,
        )

        workflow.reload
        nodes = workflow.nodes
        connections = workflow.connections
        expect(connections).to eq(
          "Topic Created" => {
            "main" => [[{ "node" => "Topic Tags", "type" => "main", "index" => 0 }]],
          },
          "Topic Tags" => {
            "main" => [[{ "node" => "Log", "type" => "main", "index" => 0 }]],
          },
        )
        expect(nodes.map { |node| node["id"] }).to eq(%w[node-1 node-2 node-3])
      end
    end

    context "with unsupported node JSON keys" do
      let(:nodes_data) { [{ id: "node-1", type: "trigger:manual", settings: {}, name: "Manual" }] }

      it "rejects the graph" do
        result =
          described_class.call(workflow: workflow, nodes_data: nodes_data, connections_data: {})

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          I18n.t("discourse_workflows.errors.invalid_node_json_keys"),
        )
      end
    end

    context "with malformed node fields" do
      it "rejects the graph before normalizing node data" do
        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "node-1", type: "trigger:manual", name: "Manual", parameters: "bad" },
            ],
            connections_data: {
            },
          )

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          I18n.t("discourse_workflows.errors.invalid_node_fields"),
        )
      end
    end

    context "when an executable node is missing a name" do
      it "rejects the graph" do
        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [{ id: "node-1", type: "trigger:manual" }],
            connections_data: {
            },
          )

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          I18n.t("discourse_workflows.errors.node_names_required"),
        )
      end
    end

    context "when two executable nodes share the same name" do
      it "rejects the graph" do
        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "node-1", type: "trigger:manual", name: "Step" },
              { id: "node-2", type: "action:log", name: "Step" },
            ],
            connections_data: {
            },
          )

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          I18n.t("discourse_workflows.errors.duplicate_node_names", names: "Step"),
        )
      end
    end

    context "when a sticky note shares its name with an executable node" do
      it "rejects the graph" do
        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "node-1", type: "trigger:manual", name: "Sticky Note" },
              { id: "note-1", type: "flow:sticky_note", name: "Sticky Note" },
            ],
            connections_data: {
            },
          )

        expect(result).to eq(false)
        expect(workflow.errors.full_messages).to include(
          I18n.t("discourse_workflows.errors.duplicate_node_names", names: "Sticky Note"),
        )
      end
    end

    context "when two sticky notes share the same default name" do
      it "accepts the graph" do
        result =
          described_class.call(
            workflow: workflow,
            nodes_data: [
              { id: "note-1", type: "flow:sticky_note", name: "Sticky Note" },
              { id: "note-2", type: "flow:sticky_note", name: "Sticky Note" },
            ],
            connections_data: {
            },
          )

        expect(result).to eq(true)
        expect(workflow.reload.nodes.map { |node| node["name"] }).to eq(
          ["Sticky Note", "Sticky Note"],
        )
      end
    end

    context "with a sparse multi-output connection map" do
      let(:nodes_data) do
        [
          { id: "node-1", type: "condition:if", name: "If" },
          { id: "node-2", type: "action:log", name: "Log" },
        ]
      end
      let(:connections_data) do
        { "If" => { "main" => [nil, [{ "node" => "Log", "type" => "main", "index" => 0 }]] } }
      end

      it "stores empty arrays instead of null output slots" do
        described_class.call(
          workflow: workflow,
          nodes_data: nodes_data,
          connections_data: connections_data,
        )

        expect(workflow.reload.connections).to eq(
          "If" => {
            "main" => [[], [{ "node" => "Log", "type" => "main", "index" => 0 }]],
          },
        )
      end
    end

    context "with split node data" do
      it "stores parameters, credentials, and direct node settings separately" do
        described_class.call(
          workflow: workflow,
          nodes_data: [
            {
              id: "http-1",
              type: "action:http_request",
              name: "HTTP request",
              notes: "Fetches data",
              alwaysOutputData: true,
              parameters: {
                "url" => "https://example.com",
                "method" => "GET",
                "authentication" => "basic_auth",
              },
              credentials: {
                "auth" => {
                  "id" => 12,
                  "credential_type" => "basic_auth",
                },
              },
            },
          ],
          connections_data: {
          },
        )

        node = workflow.reload.nodes.first
        expect(node["parameters"]).to eq(
          "url" => "https://example.com",
          "method" => "GET",
          "authentication" => "basic_auth",
        )
        expect(node["credentials"]).to eq(
          "auth" => {
            "id" => "12",
            "credential_type" => "basic_auth",
          },
        )
        expect(node["notes"]).to eq("Fetches data")
        expect(node["alwaysOutputData"]).to eq(true)
        expect(node).not_to have_key("settings")
      end

      it "removes stale credentials when authentication no longer uses them" do
        described_class.call(
          workflow: workflow,
          nodes_data: [
            {
              id: "http-1",
              type: "action:http_request",
              name: "HTTP request",
              parameters: {
                "url" => "https://example.com",
                "method" => "GET",
                "authentication" => "none",
              },
              credentials: {
                "auth" => {
                  "id" => "12",
                  "credential_type" => "basic_auth",
                },
              },
            },
          ],
          connections_data: {
          },
        )

        expect(workflow.reload.nodes.first["credentials"]).to eq({})
      end
    end

    context "when workflow has existing nodes and connections" do
      before do
        extra =
          build_workflow_graph do |g|
            g.node "existing-1", "action:topic_tags", name: "Existing Node 1"
            g.node "existing-2", "action:topic_tags", name: "Existing Node 2"
            g.chain "existing-1", "existing-2"
          end
        workflow.update!(nodes: extra[:nodes], connections: extra[:connections])
      end

      it "removes stale nodes and creates new ones" do
        described_class.call(
          workflow: workflow,
          nodes_data: [{ id: "new-1", type: "trigger:topic_created", name: "New Node" }],
          connections_data: {
          },
        )

        workflow.reload
        expect(workflow.nodes.map { |n| n["name"] }).to eq(["New Node"])
        expect(workflow.connections).to be_empty
      end

      it "preserves the existing node's id and typeVersion" do
        described_class.call(
          workflow: workflow,
          nodes_data: [
            {
              id: "existing-1",
              type: "action:topic_tags",
              name: "Updated Name",
              parameters: {
                "tag_names" => "new",
              },
            },
          ],
          connections_data: {
          },
        )

        node = workflow.reload.nodes.first
        expect(node["id"]).to eq("existing-1")
        expect(node["typeVersion"]).to eq("1.0")
        expect(node["name"]).to eq("Updated Name")
      end

      it "preserves static_data for removed nodes" do
        workflow.update!(
          static_data: {
            "global" => {
              "tenant_id" => "acme",
            },
            "node:Kept Node" => {
              "key" => "value",
            },
            "node:Removed Node" => {
              "key" => "stale",
            },
          },
        )

        described_class.call(
          workflow: workflow,
          nodes_data: [
            { id: "existing-1", type: "action:topic_tags", name: "Kept Node", parameters: {} },
          ],
          connections_data: {
          },
        )

        workflow.reload
        expect(workflow.static_data["global"]).to eq("tenant_id" => "acme")
        expect(workflow.static_data).to include(
          "node:Kept Node" => {
            "key" => "value",
          },
          "node:Removed Node" => {
            "key" => "stale",
          },
        )
      end
    end

    context "with connections referencing non-existent client IDs" do
      let(:nodes_data) { [{ id: "node-1", type: "trigger:topic_created", name: "Topic Created" }] }

      let(:connections_data) do
        {
          "Topic Created" => {
            "main" => [[{ "node" => "Missing node", "type" => "main", "index" => 0 }]],
          },
        }
      end

      it "skips connections with invalid references" do
        described_class.call(
          workflow: workflow,
          nodes_data: nodes_data,
          connections_data: connections_data,
        )

        workflow.reload
        expect(workflow.nodes.size).to eq(1)
        expect(workflow.connections).to be_empty
      end
    end

    context "when creating a form trigger without a uuid" do
      it "assigns a generated uuid" do
        described_class.call(
          workflow: workflow,
          nodes_data: [{ id: "form-1", type: "trigger:form", name: "Form" }],
          connections_data: {
          },
        )

        workflow.reload
        expect(workflow.nodes.first["webhookId"]).to be_present
      end
    end

    context "when a form trigger already has a webhookId" do
      it "preserves the existing webhookId" do
        described_class.call(
          workflow: workflow,
          nodes_data: [
            { id: "form-1", type: "trigger:form", name: "Form", webhookId: "existing-uuid" },
          ],
          connections_data: {
          },
        )

        expect(workflow.reload.nodes.first["webhookId"]).to eq("existing-uuid")
      end
    end

    context "when an existing form trigger is updated" do
      before do
        extra =
          build_workflow_graph { |g| g.node "form-1", "trigger:form", webhook_id: "original-uuid" }
        workflow.update!(nodes: extra[:nodes])
      end

      it "preserves the original webhookId" do
        described_class.call(
          workflow: workflow,
          nodes_data: [
            {
              id: "form-1",
              type: "trigger:form",
              name: "Updated Form",
              parameters: {
                "some_field" => "value",
              },
            },
          ],
          connections_data: {
          },
        )

        node = workflow.reload.nodes.first
        expect(node["webhookId"]).to eq("original-uuid")
        expect(node.dig("parameters", "some_field")).to eq("value")
      end
    end
  end
end
