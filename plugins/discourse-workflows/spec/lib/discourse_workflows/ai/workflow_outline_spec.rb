# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Ai::WorkflowOutline do
  fab!(:admin)

  fab!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual", name: "Run"
        g.node "if-1", "condition:if", name: "Is staff"
        g.node "note-1",
               "flow:sticky_note",
               name: "Sticky Note",
               parameters: {
                 content: "Keep the markers.\n#{"x" * 2_100}",
               }
        g.node "log-1", "action:code", name: "Log"
        g.chain "trigger-1", "if-1"
        g.connect "if-1", "log-1", output: "false"
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
  end

  it "lists nodes and connections, marking truncated sticky notes" do
    outline = described_class.text(workflow)

    expect(outline).to include(
      "- trigger-1 | Run | trigger:manual",
      "- log-1 | Log | action:code",
      "- note-1 | Sticky Note | flow:sticky_note | note: \"Keep the markers.\\n",
      "[truncated, 2118 chars total]\" (full note: workflow_node_details)",
      "- Run -> Is staff",
      "- Is staff [output 1] -> Log",
    )
  end

  it "marks nodes saved on a deprecated version" do
    register_versioned_workflow_nodes(
      "action:outline_deprecated_test",
      v1_deprecation: {
        superseded_by: "2.0",
      },
    )
    graph =
      build_workflow_graph do |g|
        g.node "old-1", "action:outline_deprecated_test", name: "Old", type_version: "1.0"
        g.node "new-1", "action:outline_deprecated_test", name: "New", type_version: "2.0"
      end
    workflow.update!(**graph)

    expect(described_class.text(workflow).lines(chomp: true)).to include(
      "- old-1 | Old | action:outline_deprecated_test | deprecated: upgrade_node to move it to its replacement",
      "- new-1 | New | action:outline_deprecated_test",
    )
  end

  it "says when nodes are not shown" do
    stub_const(described_class, "MAX_NODES", 2) do
      expect(described_class.text(workflow)).to include(
        "- [truncated: 2 more nodes not shown (ids: note-1, log-1); use workflow_node_details]",
      )
    end
  end

  it "handles a workflow without nodes" do
    expect(described_class.text(nil)).to eq("The workflow has no nodes yet.")
  end
end
