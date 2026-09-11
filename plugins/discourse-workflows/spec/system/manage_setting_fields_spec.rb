# frozen_string_literal: true

RSpec.describe "Manage setting fields" do
  fab!(:admin)
  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

  let(:setting_fields_page) { PageObjects::Pages::DiscourseWorkflows::SettingFields.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(admin) }

  it "lets an admin add a field from the empty state" do
    setting_fields_page.visit_index(workflow.id)
    setting_fields_page.click_add_field_empty_state

    setting_fields_page.fill_in_label("Priority")
    setting_fields_page.fill_in_key("priority")
    setting_fields_page.submit

    expect(page).to have_current_path(
      "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/settings/fields",
    )
    new_field = workflow.setting_fields.find_by(key: "priority")
    expect(setting_fields_page).to have_setting_field(new_field)

    page.refresh
    expect(setting_fields_page).to have_setting_field(new_field)
  end

  context "with an existing field" do
    fab!(:setting_field) do
      Fabricate(
        :discourse_workflows_workflow_setting_field,
        workflow:,
        key: "priority",
        label: "Priority",
        field_type: "string",
      )
    end

    it "lets an admin add another field via the Add field button" do
      setting_fields_page.visit_index(workflow.id)
      setting_fields_page.click_add_field

      setting_fields_page.fill_in_label("Notes")
      setting_fields_page.fill_in_key("notes")
      setting_fields_page.submit

      expect(page).to have_current_path(
        "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/settings/fields",
      )
      expect(setting_fields_page).to have_setting_field(setting_field)
      new_field = workflow.setting_fields.find_by(key: "notes")
      expect(setting_fields_page).to have_setting_field(new_field)
    end

    it "lets an admin edit a field's label and key" do
      setting_fields_page.visit_index(workflow.id)
      setting_fields_page.click_edit(setting_field)

      expect(setting_fields_page).to have_label_value("Priority")
      expect(setting_fields_page).to have_key_value("priority")

      setting_fields_page.fill_in_label("Urgency")
      setting_fields_page.submit

      expect(page).to have_current_path(
        "/admin/plugins/discourse-workflows/workflows/#{workflow.id}/settings/fields",
      )
      expect(setting_fields_page).to have_setting_field(setting_field.reload)

      page.refresh
      expect(setting_fields_page).to have_setting_field(setting_field.reload)
    end

    it "lets an admin delete a field after confirming" do
      setting_fields_page.visit_index(workflow.id)
      setting_fields_page.click_delete(setting_field)
      dialog.click_yes

      expect(setting_fields_page).to have_no_setting_field(setting_field)

      page.refresh
      expect(setting_fields_page).to have_no_setting_field(setting_field)
    end

    it "keeps the field when the admin cancels the delete confirmation" do
      setting_fields_page.visit_index(workflow.id)
      setting_fields_page.click_delete(setting_field)
      dialog.click_no

      expect(setting_fields_page).to have_setting_field(setting_field)
    end
  end
end
