# frozen_string_literal: true

RSpec.describe "Data Explorer AI query generation" do
  fab!(:admin)

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in admin
  end

  context "when ai queries setting is disabled" do
    before { SiteSetting.data_explorer_ai_queries_enabled = false }

    it "shows only the manual form with no mode switch" do
      visit("/admin/plugins/discourse-data-explorer/queries/new")

      expect(page).to have_css(".query-new")
      expect(page).to have_no_css(".query-mode-switch")
      expect(page).to have_css(".query-new__manual-form")
      expect(page).to have_no_css(".query-new__ai-section")
    end
  end

  context "when ai queries setting is enabled" do
    before { SiteSetting.data_explorer_ai_queries_enabled = true }

    it "shows the AI form with generate button by default" do
      visit("/admin/plugins/discourse-data-explorer/queries/new")

      expect(page).to have_css(".query-mode-switch")
      expect(page).to have_css(".query-new__ai-label", text: "Generate with AI")
      expect(page).to have_css(".query-new__ai-textarea")
      expect(page).to have_button("Generate")
    end

    it "toggles between AI and manual forms via the mode switch" do
      visit("/admin/plugins/discourse-data-explorer/queries/new")

      find(".query-mode-switch .d-segmented-control__label", text: "Write SQL").click
      expect(page).to have_css(".query-new__manual-form")
      expect(page).to have_no_css(".query-new__ai-section")

      find(".query-mode-switch .d-segmented-control__label", text: "Generate with AI").click
      expect(page).to have_css(".query-new__ai-section")
      expect(page).to have_no_css(".query-new__manual-form")
    end
  end
end
