# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-workflows/db/migrate/20260722140536_copy_workflow_trigger_category_id_to_category_ids",
        )

RSpec.describe CopyWorkflowTriggerCategoryIdToCategoryIds do
  subject(:migration) { described_class.new }

  fab!(:workflow, :discourse_workflows_workflow)

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  def build_node(type:, parameters:, id: "node-1")
    { "id" => id, "type" => type, "parameters" => parameters }
  end

  def set_workflow_nodes(nodes)
    workflow.update_columns(nodes: nodes)
  end

  def workflow_nodes
    workflow.reload.nodes
  end

  it "copies a scalar category_id into a category_ids array and keeps the legacy key" do
    set_workflow_nodes(
      [build_node(type: "trigger:topic_created", parameters: { "category_id" => "12" })],
    )

    migration.up

    parameters = workflow_nodes.first["parameters"]
    expect(parameters["category_ids"]).to eq(["12"])
    expect(parameters["category_id"]).to eq("12")
    expect(parameters).not_to have_key("include_subcategories")
  end

  it "preserves numeric and expression category_id values verbatim" do
    set_workflow_nodes(
      [
        build_node(type: "trigger:topic_created", parameters: { "category_id" => 12 }, id: "a"),
        build_node(
          type: "trigger:post_created",
          parameters: {
            "category_id" => "=$json.category_id",
          },
          id: "b",
        ),
      ],
    )

    migration.up

    expect(workflow_nodes.map { |node| node["parameters"]["category_ids"] }).to eq(
      [[12], ["=$json.category_id"]],
    )
  end

  it "overwrites an explicit null category_ids with the copied value" do
    set_workflow_nodes(
      [
        build_node(
          type: "trigger:topic_created",
          parameters: {
            "category_id" => "12",
            "category_ids" => nil,
          },
        ),
      ],
    )

    migration.up

    expect(workflow_nodes.first["parameters"]["category_ids"]).to eq(["12"])
  end

  it "does not add category_ids for a blank category_id" do
    set_workflow_nodes(
      [build_node(type: "trigger:topic_created", parameters: { "category_id" => "" })],
    )

    migration.up

    parameters = workflow_nodes.first["parameters"]
    expect(parameters).not_to have_key("category_ids")
    expect(parameters["category_id"]).to eq("")
  end

  it "does not touch include_subcategories" do
    set_workflow_nodes(
      [
        build_node(type: "trigger:topic_closed", parameters: { "category_id" => "3" }, id: "a"),
        build_node(
          type: "trigger:topic_created",
          parameters: {
            "category_id" => "3",
            "include_subcategories" => false,
          },
          id: "b",
        ),
      ],
    )

    migration.up

    nodes_by_id = workflow_nodes.index_by { |node| node["id"] }
    expect(nodes_by_id["a"]["parameters"]).not_to have_key("include_subcategories")
    expect(nodes_by_id["b"]["parameters"]["include_subcategories"]).to eq(false)
  end

  it "leaves non-trigger nodes and already-migrated nodes untouched" do
    nodes = [
      build_node(type: "action:topic", parameters: { "category_id" => "5" }, id: "a"),
      build_node(
        type: "trigger:topic_created",
        parameters: {
          "category_id" => "5",
          "category_ids" => ["7"],
        },
        id: "b",
      ),
    ]
    set_workflow_nodes(nodes)

    migration.up

    expect(workflow_nodes).to eq(nodes)
  end

  it "is idempotent and preserves node ordering" do
    set_workflow_nodes(
      [
        build_node(type: "trigger:topic_created", parameters: { "category_id" => "12" }, id: "a"),
        build_node(type: "action:post", parameters: { "operation" => "create" }, id: "b"),
      ],
    )

    migration.up
    first_pass = workflow_nodes
    migration.up

    expect(workflow_nodes).to eq(first_pass)
    expect(workflow_nodes.map { |node| node["id"] }).to eq(%w[a b])
  end

  it "migrates workflow version snapshots" do
    node = build_node(type: "trigger:topic_created", parameters: { "category_id" => "12" })
    DiscourseWorkflows::WorkflowVersion.where(workflow_id: workflow.id).update_all(nodes: [node])

    migration.up

    version_nodes = DiscourseWorkflows::WorkflowVersion.find_by(workflow_id: workflow.id).nodes
    expect(version_nodes.first["parameters"]["category_ids"]).to eq(["12"])
  end

  it "migrates execution data snapshots" do
    node = build_node(type: "trigger:topic_created", parameters: { "category_id" => "12" })
    execution_data = Fabricate(:discourse_workflows_execution_data)
    execution_data.update_columns(workflow_data: { "nodes" => [node] })

    migration.up

    reloaded_nodes = execution_data.reload.workflow_data["nodes"]
    expect(reloaded_nodes.first["parameters"]["category_ids"]).to eq(["12"])
  end

  it "migrates webhook workflow snapshots" do
    node = build_node(type: "trigger:topic_created", parameters: { "category_id" => "12" })
    DB.exec(<<~SQL, workflow_id: workflow.id, snapshot: { "nodes" => [node] }.to_json)
      INSERT INTO discourse_workflows_webhooks
        (workflow_id, node_name, webhook_path, http_method, workflow_snapshot)
      VALUES (:workflow_id, 'Webhook', '/spec-webhook', 'POST', :snapshot::jsonb)
    SQL

    migration.up

    snapshot =
      DB.query_single(
        "SELECT workflow_snapshot FROM discourse_workflows_webhooks WHERE workflow_id = :workflow_id",
        workflow_id: workflow.id,
      ).first
    expect(snapshot["nodes"].first["parameters"]["category_ids"]).to eq(["12"])
  end
end
