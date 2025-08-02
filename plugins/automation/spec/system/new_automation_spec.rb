# frozen_string_literal: true

describe "DiscourseAutomation | New automation", type: :system do
  fab!(:admin)

  before do
    SiteSetting.discourse_automation_enabled = true
    sign_in(admin)
  end

  let(:new_automation_page) { PageObjects::Pages::NewAutomation.new }

  context "when a script is clicked" do
    it "navigates to automation edit route" do
      new_automation_page.visit

      find(".admin-section-landing-item__content", match: :first).click

      expect(page).to have_css(".scriptables")
    end
  end
end
