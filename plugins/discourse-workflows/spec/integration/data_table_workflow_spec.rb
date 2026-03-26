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

  fab!(:trigger_node) do
    Fabricate(
      :discourse_workflows_node,
      workflow: workflow,
      type: "trigger:post_created",
      name: "trigger",
      configuration: {
        category_ids: [category.id],
      },
    )
  end

  fab!(:insert_node) do
    Fabricate(
      :discourse_workflows_node,
      workflow: workflow,
      type: "action:data_table",
      name: "insert_row",
      configuration: {
        "operation" => "insert",
        "data_table_id" => data_table.id.to_s,
        "columns" => {
          "topic_id" => "={{ $json.topic_id }}",
          "author" => "={{ $json.username }}",
          "logged" => "true",
        },
      },
    )
  end

  fab!(:connection) do
    Fabricate(
      :discourse_workflows_connection,
      workflow: workflow,
      source_node: trigger_node,
      target_node: insert_node,
      source_output: "main",
      target_input: "main",
    )
  end

  before do
    SiteSetting.discourse_workflows_enabled = true

    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::PostCreated::V1)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::DataTable::V1)
  end

  after { DiscourseWorkflows::Registry.reset! }

  it "inserts a data table row when a post is created" do
    topic = Fabricate(:topic, category: category, user: admin)
    trigger_data = {
      "post_id" => 1,
      "topic_id" => topic.id,
      "username" => admin.username,
      "category_id" => category.id,
      "raw" => "test post",
    }

    execution = DiscourseWorkflows::Executor.new(trigger_node, trigger_data).run

    expect(execution.status).to eq("success")
    expect(count_data_table_rows(data_table)).to eq(1)

    row = list_data_table_rows(data_table)[:rows].first
    expect(row).to include("topic_id" => topic.id, "author" => admin.username, "logged" => true)
  end
end
