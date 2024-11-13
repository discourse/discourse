# frozen_string_literal: true

describe "DiscourseAutomation | error", type: :system do
  fab!(:admin)

  let(:new_automation_page) { PageObjects::Pages::NewAutomation.new }
  let(:automation_page) { PageObjects::Pages::Automation.new }

  before do
    SiteSetting.discourse_automation_enabled = true
    sign_in(admin)
  end

  context "when saving the form with an error" do
    it "shows the error correctly" do
      new_automation_page.visit
      find(".admin-section-landing__header-filter").set("create a post")
      find(".admin-section-landing-item", match: :first).click

      automation_page.set_name("aaaaa").set_triggerables("recurring").update

      expect(automation_page).to have_error(
        I18n.t(
          "discourse_automation.models.fields.required_field",
          { name: "topic", target: "script", target_name: "post" },
        ),
      )
      expect(automation_page).to have_name("aaaaa")
    end
  end
end
