# frozen_string_literal: true

RSpec.describe "Edit setting field values" do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }
  fab!(:priority_field) do
    Fabricate(
      :discourse_workflows_workflow_setting_field,
      workflow:,
      key: "priority",
      label: "Priority",
      field_type: "string",
    )
  end
  fab!(:owner_field) do
    Fabricate(
      :discourse_workflows_workflow_setting_field,
      workflow:,
      key: "owner",
      label: "Owner",
      field_type: "string",
    )
  end

  let(:settings_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowSettings.new }

  before { sign_in(admin) }

  it "saves a field's value without disturbing a sibling field's unsaved edit" do
    settings_page.visit(workflow.id)

    settings_page.fill_in_field_value(owner_field, "alice")
    settings_page.fill_in_field_value(priority_field, "urgent")
    settings_page.save_field_value(priority_field)

    expect(settings_page).to have_field_value(owner_field, "alice")

    page.refresh
    expect(settings_page).to have_field_value(priority_field, "urgent")
  end
end
