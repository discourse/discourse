# frozen_string_literal: true

RSpec.describe "AI Usage Admin Page", type: :system do
  fab!(:admin)
  fab!(:llm_model)

  let(:ai_usage_page) { PageObjects::Pages::AiUsage.new }

  def create_usage(model, feature: "summarize", created_at: 1.day.ago)
    AiApiRequestStat.create!(
      provider_id: 1,
      feature_name: feature,
      language_model: model.name,
      llm_id: model.id,
      request_tokens: 100,
      response_tokens: 50,
      created_at:,
    )
  end

  before do
    enable_current_plugin
    sign_in(admin)
  end

  context "when viewing usage data" do
    before do
      create_usage(llm_model, feature: "summarize")
      create_usage(llm_model, feature: "translate", created_at: 2.days.ago)
    end

    it "displays total rows in tables" do
      ai_usage_page.visit

      expect(page).to have_css(".ai-usage__features-table .ai-usage__total-row")
      expect(page).to have_css(".ai-usage__models-table .ai-usage__total-row")
    end
  end

  context "when filtering by model" do
    fab!(:other_model) { Fabricate(:llm_model, display_name: "Other Model", name: "other-model") }

    before do
      create_usage(llm_model)
      create_usage(other_model, feature: "translate")
    end

    it "keeps all models in dropdown after selecting a filter" do
      ai_usage_page.visit

      model_selector = ai_usage_page.model_selector
      model_selector.expand
      model_selector.select_row_by_name(llm_model.display_name)

      expect(model_selector).to have_selected_name(llm_model.display_name)

      model_selector.expand
      expect(model_selector).to have_option_name(other_model.display_name)
    end
  end

  context "when changing time period" do
    fab!(:recent_model) do
      Fabricate(:llm_model, display_name: "Recent Model", name: "recent-model")
    end
    fab!(:old_model) { Fabricate(:llm_model, display_name: "Old Model", name: "old-model") }

    before do
      create_usage(recent_model, created_at: 6.hours.ago)
      create_usage(old_model, feature: "translate", created_at: 5.days.ago)
    end

    it "updates model dropdown to reflect the selected period" do
      ai_usage_page.visit

      model_selector = ai_usage_page.model_selector
      model_selector.expand
      expect(model_selector).to have_option_name(recent_model.display_name)
      expect(model_selector).to have_option_name(old_model.display_name)
      model_selector.collapse

      ai_usage_page.select_period(:day)

      model_selector.expand
      expect(model_selector).to have_option_name(recent_model.display_name)
      expect(model_selector).to have_no_option_name(old_model.display_name)
    end
  end
end
