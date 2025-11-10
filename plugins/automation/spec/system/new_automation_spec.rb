# frozen_string_literal: true

describe "DiscourseAutomation | New automation", type: :system do
  fab!(:admin)

  before do
    SiteSetting.discourse_automation_enabled = true
    sign_in(admin)
  end

  let(:new_automation_page) { PageObjects::Pages::NewAutomation.new }
  let(:composer) { PageObjects::Components::Composer.new }

  context "when a script is clicked" do
    it "navigates to automation edit route" do
      new_automation_page.visit

      find(
        ".admin-section-landing-item__content",
        text: I18n.t("discourse_automation.scriptables.post.title"),
      ).click
      new_automation_page.select_trigger("recurring")

      expect(page).to have_css(".scriptables")
      expect(composer).to have_rich_editor
    end
  end
end
