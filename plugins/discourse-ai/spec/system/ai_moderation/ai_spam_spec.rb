# frozen_string_literal: true

RSpec.describe "AI Spam Configuration" do
  fab!(:admin)

  before do
    enable_current_plugin
    sign_in(admin)
  end

  context "when no LLMs are configured" do
    it "shows the placeholder when no LLM is configured" do
      visit "/admin/plugins/discourse-ai/ai-spam"

      expect(page).to have_css(".ai-spam__llm-placeholder")

      toggle = PageObjects::Components::DToggleSwitch.new(".ai-spam__toggle")

      toggle.toggle
      dialog = PageObjects::Components::Dialog.new
      expect(dialog).to have_content(I18n.t("discourse_ai.spam_detection.model_missing"))
      dialog.click_ok

      expect(toggle.unchecked?).to eq(true)
    end
  end

  context "when LLMs are configured" do
    fab!(:llm_model)
    it "can properly configure spam settings" do
      visit "/admin/plugins/discourse-ai/ai-spam"

      toggle = PageObjects::Components::DToggleSwitch.new(".ai-spam__toggle")
      toggle.toggle

      expect(AiModerationSetting.spam&.llm_model_id).to eq(llm_model.id)

      find(".ai-spam__instructions-input").fill_in(with: "Test spam detection instructions")
      find(".ai-spam__instructions-save").click

      toasts = PageObjects::Components::Toasts.new
      expect(toasts).to have_content(I18n.t("js.discourse_ai.spam.settings_saved"))

      expect(AiModerationSetting.spam.custom_instructions).to eq("Test spam detection instructions")

      visit "/admin/plugins/discourse-ai/ai-models"

      expect(find(".ai-llm-list-editor__usages")).to have_content(
        I18n.t("js.discourse_ai.llms.usage.ai_spam"),
      )
    end

    it "can detect spam with only a decision model" do
      decision_model = Fabricate(:decision_model)
      visit "/admin/plugins/discourse-ai/ai-spam"

      PageObjects::Components::SelectKit.new(
        ".ai-spam__decision-model-selector",
      ).select_row_by_value(decision_model.id)
      llm_selector = PageObjects::Components::SelectKit.new(".ai-spam__llm-selector")
      llm_selector.expand
      llm_selector.select_row_by_index(0)
      expect(page).to have_no_css(".ai-spam__agent-selector")

      find(".ai-spam__instructions-save").click
      expect(PageObjects::Components::Toasts.new).to have_content(
        I18n.t("js.discourse_ai.spam.settings_saved"),
      )
      expect(AiModerationSetting.spam.slice(:llm_model_id, :decision_model_id)).to eq(
        "llm_model_id" => nil,
        "decision_model_id" => decision_model.id,
      )
    end
  end
end
