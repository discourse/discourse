# frozen_string_literal: true

RSpec.describe "Data Explorer AI query generation" do
  fab!(:admin)

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in admin
  end

  context "when ai queries setting is disabled" do
    before { SiteSetting.data_explorer_ai_queries_enabled = false }

    it "does not show the AI section" do
      visit("/admin/plugins/discourse-data-explorer/queries/new")

      expect(page).to have_css(".query-new")
      expect(page).to have_no_css(".query-new--ai-first")
    end
  end

  context "when ai queries setting is enabled" do
    before { SiteSetting.data_explorer_ai_queries_enabled = true }

    it "shows the AI-first form with generate button" do
      visit("/admin/plugins/discourse-data-explorer/queries/new")

      expect(page).to have_css(".query-new--ai-first")
      expect(page).to have_css(".query-new__ai-label", text: "Generate with AI")
      expect(page).to have_css(".query-new__ai-textarea")
      expect(page).to have_button("Generate")
      expect(page).to have_button("Write SQL manually")
    end

    it "toggles between AI and manual forms" do
      visit("/admin/plugins/discourse-data-explorer/queries/new")

      find(".query-new__toggle-link", text: "Write SQL manually").click
      expect(page).to have_css(".query-new__manual-form")
      expect(page).to have_no_css(".query-new__ai-section")

      find(".query-new__toggle-link", text: "Generate with AI").click
      expect(page).to have_css(".query-new__ai-section")
      expect(page).to have_no_css(".query-new__manual-form")
    end
  end
end
