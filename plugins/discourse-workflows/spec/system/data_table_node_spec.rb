# frozen_string_literal: true

RSpec.describe "Discourse Workflows | data table node" do
  fab!(:admin)
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      columns: [
        { "name" => "key", "type" => "string" },
        { "name" => "val", "type" => "string" },
        { "name" => "val2", "type" => "string" },
      ],
    )
  end

  let(:editor_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowEditor.new }

  before { sign_in(admin) }

  def workflow_with_update_node(columns)
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:manual", name: "Manual trigger"
        g.node "update-1",
               "action:data_table",
               name: "Update row",
               configuration: {
                 "operation" => "update",
                 "data_table_id" => data_table.id.to_s,
                 "filter" => [
                   {
                     "columnName" => "key",
                     "operator" => {
                       "type" => "string",
                       "operation" => "equals",
                       "singleValue" => false,
                     },
                     "value" => "1",
                   },
                 ],
                 "columns" => columns,
               }
        g.chain "trigger-1", "update-1"
      end
    workflow.update!(**graph)
    workflow
  end

  def saved_columns(workflow)
    workflow.reload.find_node("update-1")["parameters"]["columns"]
  end

  it "does not write a removed column and flags a cleared expression" do
    workflow = workflow_with_update_node({ "val2" => "={{ 1 }}" })

    editor_page.visit_node(workflow, "update-1")
    expect(editor_page).to have_data_table_column("val2")

    editor_page.add_data_table_column("val")
    editor_page.fill_data_table_column("val", with: "changed")
    try_until_success do
      expect(saved_columns(workflow)).to eq("val2" => "={{ 1 }}", "val" => "changed")
    end

    editor_page.remove_data_table_column("val")
    try_until_success { expect(saved_columns(workflow)).to eq("val2" => "={{ 1 }}") }

    page.refresh
    expect(editor_page).to have_node_configurator
    expect(editor_page).to have_no_data_table_column("val")

    editor_page.clear_data_table_column_expression("val2")

    expect(editor_page).to have_data_table_column_error(
      "val2",
      I18n.t(
        "js.discourse_workflows.parameter_field.empty_expression",
        plain: I18n.t("js.discourse_workflows.parameter_field.plain"),
      ),
    )
    try_until_success { expect(saved_columns(workflow)).to eq("val2" => "=") }
  end
end
