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
end
