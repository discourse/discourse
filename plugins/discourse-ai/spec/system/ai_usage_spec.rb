# frozen_string_literal: true

RSpec.describe "AI Usage Admin Page", type: :system do
  fab!(:admin)
  fab!(:llm_model)

  let(:ai_usage_page) { PageObjects::Pages::AiUsage.new }

  before do
    enable_current_plugin
    sign_in(admin)
  end

  context "when viewing usage data with total rows" do
    before do
      AiApiRequestStat.create!(
        provider_id: 1,
        feature_name: "summarize",
        language_model: llm_model.name,
        llm_id: llm_model.id,
        request_tokens: 100,
        response_tokens: 50,
        created_at: 1.day.ago,
      )

      AiApiRequestStat.create!(
        provider_id: 1,
        feature_name: "translate",
        language_model: llm_model.name,
        llm_id: llm_model.id,
        request_tokens: 200,
        response_tokens: 100,
        created_at: 2.days.ago,
      )
    end

    it "displays total rows in the features and models tables" do
      visit "/admin/plugins/discourse-ai/ai-usage"

      expect(page).to have_css(".ai-usage__features-table .ai-usage__total-row")
      expect(page).to have_css(".ai-usage__models-table .ai-usage__total-row")

      within ".ai-usage__features-table .ai-usage__total-row" do
        expect(page).to have_content(I18n.t("js.discourse_ai.usage.total"))
      end
    end
  end

  context "when using custom date range functionality" do
    it "allows selecting custom date range without JavaScript errors" do
      visit "/admin/plugins/discourse-ai/ai-usage"
      expect(page).to have_css(".ai-usage")

      # Click custom date button to show date picker
      find(".ai-usage__period-buttons .btn-default:last-child").click
      expect(page).to have_css(".ai-usage__custom-date-pickers")

      # Set dates
      date_inputs = all(".ai-usage__custom-date-pickers input[type='date']")
      date_inputs[0].set("2025-07-01")
      date_inputs[1].set("2025-07-31")

      # Verify dates are set correctly (preview functionality)
      expect(date_inputs[0].value).to eq("2025-07-01")
      expect(date_inputs[1].value).to eq("2025-07-31")

      # Click refresh - this used to cause visual glitches and date reversion
      find(".ai-usage__custom-date-pickers .btn", text: I18n.t("js.refresh")).click

      # Wait for any potential async operations
      sleep(1)

      expect(page).to have_css(".ai-usage__summary")
    end
  end

  context "when filtering by model" do
    fab!(:other_model) { Fabricate(:llm_model, display_name: "Other Model", name: "other-model") }

    before do
      AiApiRequestStat.create!(
        provider_id: 1,
        feature_name: "summarize",
        language_model: llm_model.name,
        llm_id: llm_model.id,
        request_tokens: 100,
        response_tokens: 50,
        created_at: 1.day.ago,
      )

      AiApiRequestStat.create!(
        provider_id: 1,
        feature_name: "translate",
        language_model: other_model.name,
        llm_id: other_model.id,
        request_tokens: 200,
        response_tokens: 100,
        created_at: 1.day.ago,
      )
    end

    it "keeps all models in dropdown after selecting a filter" do
      ai_usage_page.visit

      model_selector = ai_usage_page.model_selector
      model_selector.expand
      model_selector.select_row_by_name(llm_model.display_name)

      expect(model_selector).to have_selected_name(llm_model.display_name)

      # Verify other models are still available in the dropdown
      model_selector.expand
      expect(model_selector).to have_option_name(other_model.display_name)
    end
  end
end
