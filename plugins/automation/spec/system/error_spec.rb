# frozen_string_literal: true

describe "DiscourseAutomation | error", type: :system, js: true do
  fab!(:admin)

  before do
    SiteSetting.discourse_automation_enabled = true
    sign_in(admin)
  end

  context "when saving the form with an error" do
    it "shows the error correctly" do
      visit("/admin/plugins/discourse-automation/new")
      find(".admin-section-landing__header-filter").set("create a post")
      find(".admin-section-landing-item", match: :first).click

      expect(page).to have_selector("input[name='automation-name']")

      find('input[name="automation-name"]').set("aaaaa")
      select_kit = PageObjects::Components::SelectKit.new(".triggerables")
      select_kit.expand
      select_kit.select_row_by_value("recurring")
      find(".update-automation").click

      expect(page).to have_content(
        I18n.t(
          "discourse_automation.models.fields.required_field",
          { name: "topic", target: "script", target_name: "post" },
        ),
      )

      expect(find('input[name="automation-name"]').value).to eq("aaaaa")
    end
  end
end
