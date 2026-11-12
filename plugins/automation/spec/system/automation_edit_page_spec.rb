# frozen_string_literal: true

describe "DiscourseAutomation | Edit page" do
  fab!(:admin)
  fab!(:automation) { Fabricate(:automation, enabled: true) }

  before do
    DiscourseAutomation::Scriptable.add("required_cats") do
      field :cat, component: :text, required: true
      field :dog, component: :text, required: false
    end

    DiscourseAutomation::Scriptable.add("key_value_cats") { field :cats, component: :"key-value" }

    SiteSetting.discourse_automation_enabled = true
    sign_in(admin)
  end

  let(:automation_page) { PageObjects::Pages::Automation.new }
  let(:tooltip) { PageObjects::Components::Tooltips.new("automation-enabled-toggle") }

  describe "the enabled toggle" do
    it "can turn on/off the automation" do
      automation_page.visit(automation)

      expect(automation_page.enabled_toggle).to be_checked

      automation_page.enabled_toggle.toggle
      expect(automation_page.enabled_toggle).to be_unchecked

      automation_page.enabled_toggle.toggle
      expect(automation_page.enabled_toggle).to be_checked
    end

    it "is disabled when the automation has missing required fields" do
      automation.update!(enabled: false, script: "required_cats")
      automation_page.visit(automation)

      expect(automation_page.enabled_toggle).to be_disabled
      automation_page.enabled_toggle.label_component.hover
      expect(tooltip).to be_present(
        text: I18n.t("js.discourse_automation.models.automation.enable_toggle_disabled"),
      )
    end

    it "is enabled when the automation is enabled even with missing required fields" do
      automation.update_attribute(:script, "required_cats")
      automation.fields.destroy_all

      automation_page.visit(automation)
      expect(automation_page.enabled_toggle).to be_enabled

      automation_page.enabled_toggle.toggle
      expect(automation_page.enabled_toggle).to be_unchecked
      expect(automation_page.enabled_toggle).to be_disabled
      automation_page.enabled_toggle.label_component.hover
      expect(tooltip).to be_present(
        text: I18n.t("js.discourse_automation.models.automation.enable_toggle_disabled"),
      )
    end
  end

  describe "the key-value field" do
    it "doesn't save the automation when saving the modal" do
      automation.update!(script: "key_value_cats")
      automation_page.visit(automation)

      find(".key-value-field .configure-btn").click
      modal = PageObjects::Modals::Base.new(modal_selector: ".json-schema-editor-modal")
      modal.click_primary_button

      expect(modal).to be_closed
      expect(page).to have_current_path("/admin/plugins/automation/automation/#{automation.id}")
      expect(automation.fields.where(name: "cats")).to be_empty

      automation_page.update

      expect(page).to have_current_path("/admin/plugins/automation/automation")
      expect(automation.fields.find_by(name: "cats").metadata["value"]).to be_present
    end
  end
end
