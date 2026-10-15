# frozen_string_literal: true

RSpec.describe "Edit workflow variable values" do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }
  fab!(:priority_variable) do
    Fabricate(
      :discourse_workflows_workflow_variable,
      workflow:,
      key: "priority",
      variable_type: "string",
    )
  end
  fab!(:owner_variable) do
    Fabricate(
      :discourse_workflows_workflow_variable,
      workflow:,
      key: "owner",
      variable_type: "string",
    )
  end

  let(:variables_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowVariables.new }

  before { sign_in(admin) }

  it "saves a variable's value without disturbing a sibling variable's unsaved edit" do
    variables_page.visit_index(workflow.id)

    variables_page.fill_in_variable_value(owner_variable, "alice")
    variables_page.fill_in_variable_value(priority_variable, "urgent")
    variables_page.save_variable_value(priority_variable)

    expect(variables_page).to have_variable_value(owner_variable, "alice")

    page.refresh
    expect(variables_page).to have_variable_value(priority_variable, "urgent")
  end
end
