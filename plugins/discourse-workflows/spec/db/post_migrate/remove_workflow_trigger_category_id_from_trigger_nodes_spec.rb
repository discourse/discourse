# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-workflows/db/post_migrate/20260722140539_remove_workflow_trigger_category_id_from_trigger_nodes",
        )

RSpec.describe RemoveWorkflowTriggerCategoryIdFromTriggerNodes do
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

  it "strips category_id from already-copied trigger nodes" do
    set_workflow_nodes(
      [
        build_node(
          type: "trigger:topic_created",
          parameters: {
            "category_id" => "12",
            "category_ids" => ["12"],
          },
        ),
      ],
    )

    migration.up

    parameters = workflow_nodes.first["parameters"]
    expect(parameters).not_to have_key("category_id")
    expect(parameters["category_ids"]).to eq(["12"])
  end

  it "copies then strips rows written by pre-rename code" do
    set_workflow_nodes(
      [build_node(type: "trigger:topic_closed", parameters: { "category_id" => "12" })],
    )

    migration.up

    parameters = workflow_nodes.first["parameters"]
    expect(parameters).not_to have_key("category_id")
    expect(parameters["category_ids"]).to eq(["12"])
    expect(parameters).not_to have_key("include_subcategories")
  end

  it "copies over an explicit null category_ids before stripping" do
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

    parameters = workflow_nodes.first["parameters"]
    expect(parameters).not_to have_key("category_id")
    expect(parameters["category_ids"]).to eq(["12"])
  end

  it "drops a blank category_id without adding category_ids" do
    set_workflow_nodes(
      [build_node(type: "trigger:topic_created", parameters: { "category_id" => "" })],
    )

    migration.up

    parameters = workflow_nodes.first["parameters"]
    expect(parameters).not_to have_key("category_id")
    expect(parameters).not_to have_key("category_ids")
  end

  it "leaves non-trigger nodes untouched" do
    nodes = [build_node(type: "action:topic", parameters: { "category_id" => "5" })]
    set_workflow_nodes(nodes)

    migration.up

    expect(workflow_nodes).to eq(nodes)
  end

  it "strips the legacy key from version, execution, and webhook snapshots" do
    node =
      build_node(
        type: "trigger:topic_created",
        parameters: {
          "category_id" => "12",
          "category_ids" => ["12"],
        },
      )
    DiscourseWorkflows::WorkflowVersion.where(workflow_id: workflow.id).update_all(nodes: [node])
    execution_data = Fabricate(:discourse_workflows_execution_data)
    execution_data.update_columns(workflow_data: { "nodes" => [node] })
    DB.exec(<<~SQL, workflow_id: workflow.id, snapshot: { "nodes" => [node] }.to_json)
      INSERT INTO discourse_workflows_webhooks
        (workflow_id, node_name, webhook_path, http_method, workflow_snapshot)
      VALUES (:workflow_id, 'Webhook', '/spec-webhook', 'POST', :snapshot::jsonb)
    SQL

    migration.up

    version_parameters =
      DiscourseWorkflows::WorkflowVersion.find_by(workflow_id: workflow.id).nodes.first[
        "parameters"
      ]
    expect(version_parameters).not_to have_key("category_id")

    execution_parameters = execution_data.reload.workflow_data["nodes"].first["parameters"]
    expect(execution_parameters).not_to have_key("category_id")

    webhook_snapshot =
      DB.query_single(
        "SELECT workflow_snapshot FROM discourse_workflows_webhooks WHERE workflow_id = :workflow_id",
        workflow_id: workflow.id,
      ).first
    expect(webhook_snapshot["nodes"].first["parameters"]).not_to have_key("category_id")
  end
end
