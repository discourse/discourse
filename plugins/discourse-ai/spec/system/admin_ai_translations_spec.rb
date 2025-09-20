# frozen_string_literal: true

RSpec.describe "Admin AI translations", type: :system do
  fab!(:admin)
  let(:page_header) { PageObjects::Components::DPageHeader.new }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)

    allow(DiscourseAi::Translation).to receive(:has_llm_model?).and_return(true)
    allow(DiscourseAi::Translation::PostCandidates).to receive(
      :get_completion_per_locale,
    ).and_return({ total: 100, done: 50 })

    sign_in(admin)
  end

  describe "when translations are enabled" do
    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_translation_enabled = true
      SiteSetting.content_localization_supported_locales = "en|fr|es"
      SiteSetting.ai_translation_backfill_hourly_rate = 10
      SiteSetting.ai_translation_backfill_max_age_days = 30

      visit "/admin/plugins/discourse-ai/ai-translations"
    end

    it "displays the translations page with chart" do
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.title"))
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.description"))

      # Verify the action buttons are present with their CSS classes
      expect(page).to have_css(".ai-translation-settings-button")
      expect(page).to have_css(".ai-localization-settings-button")

      # Verify chart container is present
      expect(page).to have_css(".ai-translation__charts")
      expect(page).to have_css(".ai-translation__chart")
    end

    it "navigates to translation settings when clicking the settings button" do
      translation_id = DiscourseAi::Configuration::Module::TRANSLATION_ID
      find(".ai-translation-settings-button").click

      # Verify we navigated to the correct route
      expect(page).to have_current_path(
        "/admin/plugins/discourse-ai/ai-features/#{translation_id}/edit",
      )
    end

    it "navigates to localization settings when clicking the localization button" do
      find(".ai-localization-settings-button").click

      # Verify we navigated to the correct route
      expect(page).to have_current_path("/admin/config/localization")
    end
  end

  describe "when translations are disabled" do
    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_translation_enabled = false
      SiteSetting.content_localization_supported_locales = "en|fr|es"

      visit "/admin/plugins/discourse-ai/ai-translations"
    end

    it "displays the disabled state message and configure button" do
      expect(page).to have_content(
        I18n.t("js.discourse_ai.translations.admin_actions.disabled_state.empty_label"),
      )
      expect(page).to have_css(".ai-translations__configure-button")

      # Verify chart is NOT shown
      expect(page).to have_no_css(".ai-translation__chart")
    end

    it "navigates to translation settings when clicking the configure button" do
      translation_id = DiscourseAi::Configuration::Module::TRANSLATION_ID
      find(".ai-translations__configure-button").click

      # Verify we navigated to the correct route
      expect(page).to have_current_path(
        "/admin/plugins/discourse-ai/ai-features/#{translation_id}/edit",
      )
    end
  end
end
