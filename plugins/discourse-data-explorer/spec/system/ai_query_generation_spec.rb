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
      expect(page).to have_css(".query-new [data-name='name']")
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

  context "when on the edit page" do
    fab!(:query) { Fabricate(:query, name: "Existing query", sql: "SELECT 1", user: admin) }

    before { SiteSetting.data_explorer_ai_queries_enabled = true }

    it "shows the AI prompt and view segmented control (with SQL option) by default in AI mode" do
      visit("/admin/plugins/discourse-data-explorer/queries/#{query.id}")

      expect(page).to have_css(".query-ai-prompt")
      expect(page).to have_css(".query-results-modes input[value='sql']", visible: :all)

      find(".query-mode-switch .d-segmented-control__label", text: "Write SQL").click

      expect(page).to have_no_css(".query-ai-prompt")
      expect(page).to have_no_css(".query-results-modes input[value='sql']", visible: :all)
    end

    it "keeps Re-generate disabled until the prompt is non-empty" do
      visit("/admin/plugins/discourse-data-explorer/queries/#{query.id}")

      expect(page).to have_css(".query-ai-prompt__regenerate[disabled]")

      fill_in("query-ai-prompt-input", with: "show me popular topics")

      expect(page).to have_no_css(".query-ai-prompt__regenerate[disabled]")
    end

    it "switches between SQL, chart, and table views via the segmented control" do
      visit("/admin/plugins/discourse-data-explorer/queries/#{query.id}")

      # Default in AI mode is SQL — editor visible, results hidden
      expect(page).to have_css(".query-editor")
      expect(page).to have_no_css(".query-results")

      page.execute_script(
        "document.querySelector(\".query-results-modes input[value='table']\").closest('label').click()",
      )
      expect(page).to have_no_css(".query-editor")
      expect(page).to have_no_css(".sql")

      page.execute_script(
        "document.querySelector(\".query-results-modes input[value='sql']\").closest('label').click()",
      )
      expect(page).to have_css(".query-editor")
    end

    it "clears the prompt when switching back to manual mode" do
      visit("/admin/plugins/discourse-data-explorer/queries/#{query.id}")
      fill_in("query-ai-prompt-input", with: "hello")

      find(".query-mode-switch .d-segmented-control__label", text: "Write SQL").click
      find(".query-mode-switch .d-segmented-control__label", text: "Generate with AI").click

      expect(page).to have_field("query-ai-prompt-input", with: "")
    end
  end

  context "when on the edit page for a default query" do
    before { SiteSetting.data_explorer_ai_queries_enabled = true }

    it "disables the AI option in the mode switch" do
      visit("/admin/plugins/discourse-data-explorer/queries/-1")

      expect(page).to have_css(".query-mode-switch input[value='manual']:checked", visible: :all)
      expect(page).to have_css(".query-mode-switch input[value='ai'][disabled]", visible: :all)
      expect(page).to have_no_css(".query-ai-prompt")
    end
  end

  context "when remembering the last used mode" do
    fab!(:query) { Fabricate(:query, name: "First query", sql: "SELECT 1", user: admin) }
    fab!(:other_query) { Fabricate(:query, name: "Second query", sql: "SELECT 2", user: admin) }

    before { SiteSetting.data_explorer_ai_queries_enabled = true }

    it "opens subsequent queries and the new query page in the last used mode" do
      visit("/admin/plugins/discourse-data-explorer/queries/new")
      expect(page).to have_css(".query-new__ai-section")

      find(".query-new__top-bar .back-button").click
      within(".discourse-data-explorer-query-list") { click_link("First query") }
      find(".query-mode-switch .d-segmented-control__label", text: "Write SQL").click
      expect(page).to have_no_css(".query-ai-prompt")

      find(".back-button").click
      find(".d-page-subheader .btn-primary").click
      expect(page).to have_css(".query-new__manual-form")
      expect(page).to have_no_css(".query-new__ai-section")

      visit("/admin/plugins/discourse-data-explorer/queries/#{other_query.id}")
      expect(page).to have_css(".query-editor")
      expect(page).to have_no_css(".query-ai-prompt")
    end
  end
end
