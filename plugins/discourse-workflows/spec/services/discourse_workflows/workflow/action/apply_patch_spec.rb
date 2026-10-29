# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Action::ApplyPatch do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  let(:operations) do
    [
      {
        op: "add_node",
        client_id: "manual-trigger",
        node: {
          type: "trigger:manual",
          name: "Manual trigger",
          position: {
            x: 0,
            y: 0,
          },
        },
      },
      {
        op: "add_node",
        client_id: "write-log",
        node: {
          type: "action:log",
          name: "Write log",
          position: {
            x: 200,
            y: 0,
          },
          parameters: {
            entries: {
              values: [{ key: "message", value: "hello" }],
            },
          },
        },
      },
      { op: "add_connection", from: "manual-trigger", to: "write-log" },
    ]
  end

  it "dry-runs patch operations without changing the workflow draft" do
    result = described_class.call(workflow:, operations:, persist: false, user: admin)

    expect(result).to include(valid: true, errors: [])
    expect(result[:nodes].map { |node| node["type"] }).to contain_exactly(
      "trigger:manual",
      "action:log",
    )
    expect(workflow.reload.nodes).to eq([])
  end

  it "normalizes empty credential arrays from AI patches" do
    result =
      described_class.call(
        workflow: workflow,
        operations: [
          {
            op: "add_node",
            node: {
              type: "trigger:manual",
              typeVersion: 1,
              name: "Manual trigger",
              credentials: [],
            },
          },
        ],
        persist: false,
        user: admin,
      )

    expect(result).to include(valid: true, errors: [])
    expect(result[:nodes].first).to include("credentials" => {}, "typeVersion" => "1.0")
  end

  it "normalizes array positions from AI patches" do
    result =
      described_class.call(
        workflow: workflow,
        operations: [
          {
            op: "add_node",
            node: {
              type: "trigger:manual",
              name: "Manual trigger",
              position: [100, 200],
            },
          },
        ],
        persist: false,
        user: admin,
      )

    expect(result).to include(valid: true, errors: [])
    expect(result[:nodes].first["position"]).to eq("x" => 100.0, "y" => 200.0)
  end

  it "returns errors for malformed operations" do
    result =
      described_class.call(workflow:, operations: ["add a node"], persist: false, user: admin)

    expect(result).to include(valid: false, errors: ["Patch operation must be an object"])
    expect(workflow.reload.nodes).to eq([])
  end

  it "dry-runs prompt-only AI agent creation", :aggregate_failures do
    result =
      described_class.call(
        workflow: workflow,
        operations: [
          {
            op: "create_ai_agent",
            client_id: "triage-agent",
            agent: {
              name: "Workflow triage agent",
              description: "Classifies posts for a workflow.",
              system_prompt: "You classify Discourse posts for triage.",
            },
          },
          {
            op: "add_node",
            client_id: "classify-post",
            node: {
              type: "action:ai_agent",
              name: "Classify post",
              position: {
                x: 200,
                y: 0,
              },
              parameters: {
                agent_id: {
                  "$ref" => "triage-agent",
                },
                prompt: "={{ $json.post.raw }}",
              },
            },
          },
        ],
        persist: false,
        user: admin,
      )

    expect(result).to include(valid: true, errors: [])
    expect(result[:created_resources]).to contain_exactly(
      include(
        "type" => "ai_agent",
        "client_id" => "triage-agent",
        "name" => "Workflow triage agent",
        "system_prompt" => "You classify Discourse posts for triage.",
      ),
    )
    expect(AiAgent.find_by(name: "Workflow triage agent")).to be_nil
  end

  it "creates proposed AI agents when persisted", :aggregate_failures do
    result =
      described_class.call(
        workflow: workflow,
        operations: [
          {
            op: "create_ai_agent",
            client_id: "summary-agent",
            agent: {
              name: "Workflow summary agent",
              description: "Summarizes posts for a workflow.",
              system_prompt: "You summarize Discourse posts in one sentence.",
            },
          },
          {
            op: "add_node",
            client_id: "summarize-post",
            node: {
              type: "action:ai_agent",
              name: "Summarize post",
              parameters: {
                agent_id: {
                  "$ref" => "summary-agent",
                },
                prompt: "={{ $json.post.raw }}",
              },
            },
          },
        ],
        persist: true,
        user: admin,
      )
    created_agent = AiAgent.find_by(name: "Workflow summary agent")
    node = workflow.reload.nodes.find { |workflow_node| workflow_node["type"] == "action:ai_agent" }

    expect(result).to include(valid: true, errors: [])
    expect(created_agent).to have_attributes(
      description: "Summarizes posts for a workflow.",
      system_prompt: "You summarize Discourse posts in one sentence.",
      tools: [],
      allowed_group_ids: [],
      created_by_id: admin.id,
    )
    expect(node.dig("parameters", "agent_id")).to eq(created_agent.id)
    expect(node.dig("parameters", "agent_name")).to eq("Workflow summary agent")
  end

  it "mirrors an existing agent onto the node it is referenced from", :aggregate_failures do
    response_format = [{ "key" => "verdict", "type" => "string" }]
    agent = Fabricate(:ai_agent, name: "Workflow triage agent", response_format: response_format)

    result =
      described_class.call(
        workflow: workflow,
        operations: [
          {
            op: "add_node",
            client_id: "triage-post",
            node: {
              type: "action:ai_agent",
              name: "Triage post",
              parameters: {
                agent_id: agent.id,
                prompt: "={{ $json.post.raw }}",
              },
            },
          },
        ],
        persist: true,
        user: admin,
      )
    node = workflow.reload.nodes.find { |workflow_node| workflow_node["type"] == "action:ai_agent" }

    expect(result).to include(valid: true, errors: [])
    expect(node["parameters"]).to include(
      "agent_name" => "Workflow triage agent",
      "agent_response_format" => response_format,
    )
  end

  it "rejects unknown AI agent references" do
    result =
      described_class.call(
        workflow: workflow,
        operations: [
          {
            op: "add_node",
            client_id: "classify-post",
            node: {
              type: "action:ai_agent",
              name: "Classify post",
              parameters: {
                agent_id: {
                  "$ref" => "missing-agent",
                },
              },
            },
          },
        ],
        persist: false,
        user: admin,
      )

    expect(result).to include(
      valid: false,
      errors: ['Classify post references unknown AI agent client_id "missing-agent"'],
    )
  end

  context "with deprecated node versions" do
    before do
      register_versioned_workflow_nodes(
        "action:patch_replaced_test",
        v1_deprecation: {
          replaced_by: ["action:log"],
        },
        v1_upgrade: ->(parameters) do
          { type: "action:log", parameters: { "message" => parameters["name"] } }
        end,
      )
      register_versioned_workflow_nodes(
        "action:patch_superseded_test",
        v1_deprecation: {
          superseded_by: "2.0",
        },
      )
      workflow.update!(
        nodes: [
          saved_node("replaced-1", "action:patch_replaced_test", "1.0"),
          saved_node("superseded-1", "action:patch_superseded_test", "1.0"),
          saved_node("current-1", "action:patch_superseded_test", "2.0"),
        ],
      )
    end

    def saved_node(id, type, type_version)
      {
        "id" => id,
        "type" => type,
        "typeVersion" => type_version,
        "name" => id.titleize,
        "parameters" => {
          "name" => "Hello",
        },
      }
    end

    def apply(*operations)
      described_class.call(workflow:, operations:, persist: false, user: admin)
    end

    def node(result, id)
      result[:nodes].find { |node| node["id"] == id }
    end

    it "upgrades a deprecated node with the shared upgrader" do
      result = apply({ op: "upgrade_node", node_id: "replaced-1" })

      expect(node(result, "replaced-1")).to include(
        "type" => "action:log",
        "typeVersion" => DiscourseWorkflows::Registry.latest_version("action:log"),
        "name" => "Replaced 1",
        "parameters" => {
          "message" => "Hello",
        },
      )
    end

    it "refuses to upgrade a node that is not deprecated" do
      result = apply({ op: "upgrade_node", node_id: "current-1" })

      expect(result).to include(valid: false, errors: ["Node Current 1 is not deprecated"])
    end

    it "refuses to upgrade a node its upgrade can't move" do
      register_versioned_workflow_nodes(
        "action:patch_stuck_test",
        v1_deprecation: {
          replaced_by: ["action:log"],
        },
        v1_upgrade: ->(_parameters) { nil },
      )
      workflow.update!(nodes: [saved_node("stuck-1", "action:patch_stuck_test", "1.0")])

      result = apply({ op: "upgrade_node", node_id: "stuck-1" })

      expect(result).to include(
        valid: false,
        errors: ["Node Stuck 1 can't be upgraded automatically"],
      )
    end

    it "refuses to edit a replaced node until it is upgraded" do
      edit = { op: "update_node_parameters", node_id: "replaced-1", parameters: { "x" => 1 } }

      expect(apply(edit)).to include(
        valid: false,
        errors: ["Node Replaced 1 was replaced, upgrade it with upgrade_node first"],
      )
      expect(
        node(apply({ op: "upgrade_node", node_id: "replaced-1" }, edit), "replaced-1"),
      ).to include("parameters" => { "message" => "Hello", "x" => 1 })
    end

    it "edits a superseded node, which keeps its parameters in the newer version" do
      result =
        apply({ op: "update_node_parameters", node_id: "superseded-1", parameters: { "x" => 1 } })

      expect(node(result, "superseded-1")).to include(
        "typeVersion" => "1.0",
        "parameters" => {
          "name" => "Hello",
          "x" => 1,
        },
      )
    end

    it "refuses to add a deprecated version" do
      result =
        apply(
          {
            op: "add_node",
            node: {
              type: "action:patch_superseded_test",
              typeVersion: "1.0",
              name: "New",
            },
          },
        )

      expect(result).to include(
        valid: false,
        errors: ["action:patch_superseded_test 1.0 is deprecated, add the latest version instead"],
      )
    end
  end
end
