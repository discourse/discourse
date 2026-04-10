# frozen_string_literal: true

RSpec.describe "Data Table workflow integration" do
  fab!(:admin)
  fab!(:category)

  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      name: "post_log",
      columns: [
        { "name" => "topic_id", "type" => "number" },
        { "name" => "author", "type" => "string" },
        { "name" => "logged", "type" => "boolean" },
      ],
    )
  end

  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, enabled: true, created_by: admin) }

  before do
    SiteSetting.discourse_workflows_enabled = true

    graph =
      build_workflow_graph do |g|
        g.node "trigger-1",
               "trigger:post_created",
               name: "trigger",
               configuration: {
                 "category_ids" => [category.id],
               }
        g.node "action-1",
               "action:data_table",
               name: "insert_row",
               configuration: {
                 "operation" => "insert",
                 "data_table_id" => data_table.id.to_s,
                 "columns" => {
                   "topic_id" => "={{ $json.topic_id }}",
                   "author" => "={{ $json.username }}",
                   "logged" => "true",
                 },
               }
        g.chain "trigger-1", "action-1"
      end

    workflow.update!(**graph)
  end

  it "inserts a data table row when a post is created" do
    topic = Fabricate(:topic, category: category, user: admin)
    trigger_data = {
      "post_id" => 1,
      "topic_id" => topic.id,
      "username" => admin.username,
      "category_id" => category.id,
      "raw" => "test post",
    }

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", trigger_data).run

    expect(execution.status).to eq("success")
    expect(count_data_table_rows(data_table)).to eq(1)

    row = list_data_table_rows(data_table)[:rows].first
    expect(row).to include("topic_id" => topic.id, "author" => admin.username, "logged" => true)
  end

  it "keeps workflow mappings working after a column rename and config update" do
    DiscourseWorkflows::DataTableColumn::Rename.call(
      params: {
        data_table_id: data_table.id,
        column_name: "author",
        name: "post_author",
      },
      guardian: admin.guardian,
    )

    nodes = workflow.nodes.deep_dup
    action_node = nodes.find { |n| n["id"] == "action-1" }
    columns = action_node["configuration"]["columns"]
    columns["post_author"] = columns.delete("author")
    workflow.update!(nodes: nodes)

    topic = Fabricate(:topic, category: category, user: admin)
    trigger_data = {
      "post_id" => 1,
      "topic_id" => topic.id,
      "username" => admin.username,
      "category_id" => category.id,
      "raw" => "test post",
    }

    execution = DiscourseWorkflows::Executor.new(workflow, "trigger-1", trigger_data).run

    expect(execution.status).to eq("success")

    row = list_data_table_rows(data_table)[:rows].first
    expect(row["post_author"]).to eq(admin.username)
  end
end
