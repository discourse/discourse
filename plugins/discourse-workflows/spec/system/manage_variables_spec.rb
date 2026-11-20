# frozen_string_literal: true

RSpec.describe "Manage workflow variables" do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  let(:variables_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowVariables.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(admin) }

  it "lets an admin add a variable from the empty state" do
    variables_page.visit_manage(workflow.id)
    variables_page.click_add_variable_empty_state

    variables_page.fill_in_key("priority")
    variables_page.submit

    expect(page).to have_current_path(
      "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/manage",
    )
    new_variable = workflow.variables.find_by(key: "priority")
    expect(variables_page).to have_variable(new_variable)

    page.refresh
    expect(variables_page).to have_variable(new_variable)
  end

  context "with an existing variable" do
    fab!(:variable) do
      Fabricate(
        :discourse_workflows_workflow_variable,
        workflow:,
        key: "priority",
        variable_type: "string",
      )
    end

    it "lets an admin add another variable via the Add variable button" do
      variables_page.visit_manage(workflow.id)
      variables_page.click_add_variable

      variables_page.fill_in_key("notes")
      variables_page.submit

      expect(page).to have_current_path(
        "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/manage",
      )
      expect(variables_page).to have_variable(variable)
      new_variable = workflow.variables.find_by(key: "notes")
      expect(variables_page).to have_variable(new_variable)
    end

    it "lets an admin edit a variable's key" do
      variables_page.visit_manage(workflow.id)
      variables_page.click_edit(variable)

      expect(variables_page).to have_key_value("priority")

      variables_page.fill_in_key("urgency")
      variables_page.submit

      expect(page).to have_current_path(
        "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/variables/manage",
      )
      expect(variables_page).to have_variable(variable.reload)

      page.refresh
      expect(variables_page).to have_variable(variable.reload)
    end

    it "lets an admin delete a variable after confirming" do
      variables_page.visit_manage(workflow.id)
      variables_page.click_delete(variable)
      dialog.click_yes

      expect(variables_page).to have_no_variable(variable)

      page.refresh
      expect(variables_page).to have_no_variable(variable)
    end

    it "keeps the variable when the admin cancels the delete confirmation" do
      variables_page.visit_manage(workflow.id)
      variables_page.click_delete(variable)
      dialog.click_no

      expect(variables_page).to have_variable(variable)
    end
  end
end
