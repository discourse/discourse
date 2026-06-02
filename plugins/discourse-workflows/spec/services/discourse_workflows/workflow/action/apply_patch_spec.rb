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

  it "returns errors for malformed operations" do
    result =
      described_class.call(workflow:, operations: ["add a node"], persist: false, user: admin)

    expect(result).to include(valid: false, errors: ["Patch operation must be an object"])
    expect(workflow.reload.nodes).to eq([])
  end
end
