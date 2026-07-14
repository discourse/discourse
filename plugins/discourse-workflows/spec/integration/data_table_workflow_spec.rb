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

  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, published: true, created_by: admin) }

  before do
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
    publish_workflow!(workflow)
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

  context "with row_exists operation" do
    fab!(:exists_workflow) do
      Fabricate(:discourse_workflows_workflow, published: true, created_by: admin)
    end

    fab!(:logger_table) do
      Fabricate(
        :discourse_workflows_data_table,
        name: "logged_topics",
        columns: [{ "name" => "topic_id", "type" => "number" }],
      )
    end

    before do
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
                 name: "row_exists",
                 configuration: {
                   "operation" => "row_exists",
                   "data_table_id" => logger_table.id.to_s,
                   "filter" => [
                     {
                       "columnName" => "topic_id",
                       "operator" => {
                         "type" => "number",
                         "operation" => "equals",
                         "singleValue" => false,
                       },
                       "value" => "={{ $json.topic_id }}",
                     },
                   ],
                 }
          g.chain "trigger-1", "action-1"
        end

      exists_workflow.update!(**graph)
      publish_workflow!(exists_workflow)
    end

    it "passes the trigger payload through when a matching row exists" do
      topic = Fabricate(:topic, category: category, user: admin)
      insert_data_table_row(logger_table, "topic_id" => topic.id)

      trigger_data = {
        "post_id" => 1,
        "topic_id" => topic.id,
        "username" => admin.username,
        "category_id" => category.id,
        "raw" => "test post",
      }

      execution = DiscourseWorkflows::Executor.new(exists_workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")

      action_step = execution.execution_data.find_step(node_id: "action-1")
      output_items = action_step["output"]
      expect(output_items.length).to eq(1)
      expect(output_items.first["json"]).to include("topic_id" => topic.id, "post_id" => 1)
      expect(output_items.first["json"]).not_to have_key("id")
    end

    it "filters out the payload when no row matches" do
      topic = Fabricate(:topic, category: category, user: admin)

      trigger_data = {
        "post_id" => 2,
        "topic_id" => topic.id,
        "username" => admin.username,
        "category_id" => category.id,
        "raw" => "test post",
      }

      execution = DiscourseWorkflows::Executor.new(exists_workflow, "trigger-1", trigger_data).run

      expect(execution.status).to eq("success")

      action_step = execution.execution_data.find_step(node_id: "action-1")
      expect(action_step["output"]).to eq([])
    end
  end

  it "writes to the renamed column once the workflow config is updated to match" do
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
    columns = action_node["parameters"]["columns"]
    columns["post_author"] = columns.delete("author")
    workflow.update!(nodes: nodes)
    publish_workflow!(workflow)

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
