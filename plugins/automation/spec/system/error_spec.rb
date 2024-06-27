# frozen_string_literal: true

describe "DiscourseAutomation | error", type: :system do
  fab!(:admin)

  before do
    SiteSetting.discourse_automation_enabled = true
    sign_in(admin)
  end

  context "when saving the form with an error" do
    it "shows the error correctly" do
      visit("/admin/plugins/discourse-automation")

      find(".new-automation").click
      fill_in("automation-name", with: "aaaaa")
      select_kit = PageObjects::Components::SelectKit.new(".scriptables")
      select_kit.expand
      select_kit.select_row_by_value("post")
      find(".create-automation").click
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
    end
  end
end
