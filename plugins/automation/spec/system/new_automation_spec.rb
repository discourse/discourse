# frozen_string_literal: true

describe "DiscourseAutomation | New automation", type: :system, js: true do
  fab!(:admin)

  before do
    SiteSetting.discourse_automation_enabled = true
    sign_in(admin)
  end

  let(:new_automation_page) { PageObjects::Pages::NewAutomation.new }

  context "when the script is not selected" do
    it "shows an error" do
      new_automation_page.visit.fill_name("aaaaa").create

      expect(new_automation_page).to have_error(I18n.t("errors.messages.blank"))
    end
  end
end
