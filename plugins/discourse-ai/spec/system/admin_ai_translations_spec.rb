# frozen_string_literal: true

RSpec.describe "Admin AI translations", type: :system do
  fab!(:admin)
  let(:page_header) { PageObjects::Components::DPageHeader.new }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)

    allow(DiscourseAi::Translation).to receive(:has_llm_model?).and_return(true)
    allow(DiscourseAi::Translation::PostCandidates).to receive(
      :get_completion_all_locales,
    ).and_return(
      {
        translation_progress: [
          { done: 50, locale: "en", total: 100 },
          { done: 50, locale: "fr", total: 100 },
          { done: 50, locale: "es", total: 100 },
        ],
        total: 300,
        posts_with_detected_locale: 150,
      },
    )

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
      expect(page).to have_css(".ai-translations__charts")
      expect(page).to have_css(".ai-translations__chart")
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
      SiteSetting.ai_translation_backfill_max_age_days = 30

      visit "/admin/plugins/discourse-ai/ai-translations"
    end

    it "shows the toggle in off state and no chart" do
      expect(page).to have_css(".d-toggle-switch")

      expect(page).to have_no_css(".ai-translations__chart")
    end

    it "shows localization settings button" do
      expect(page).to have_css(".ai-localization-settings-button")
    end
  end

  describe "when locales are not configured" do
    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_translation_enabled = false
      SiteSetting.content_localization_supported_locales = ""
      SiteSetting.ai_translation_backfill_max_age_days = 30

      visit "/admin/plugins/discourse-ai/ai-translations"
    end

    it "displays the alert with locale selector" do
      expect(page).to have_css(".alert.alert-info")
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.supported_locales"))
      expect(page).to have_css(".multi-select")
    end

    it "allows adding and saving languages" do
      find(".multi-select").click

      find(".select-kit-row[data-value='en']").click

      expect(page).to have_css(".setting-controls__ok")

      find(".setting-controls__ok").click

      expect(page).to have_no_css(".setting-controls__ok")

      expect(SiteSetting.content_localization_supported_locales).to eq("en")
    end
  end

  describe "translation toggle" do
    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.content_localization_supported_locales = "en|fr"
      SiteSetting.ai_translation_backfill_max_age_days = 30

      allow(DiscourseAi::Translation::PostCandidates).to receive(
        :get_completion_all_locales,
      ).and_return(
        {
          translation_progress: [
            { done: 50, locale: "en", total: 100 },
            { done: 50, locale: "fr", total: 100 },
          ],
          total: 200,
          posts_with_detected_locale: 100,
        },
      )
    end

    it "displays the translation toggle" do
      SiteSetting.ai_translation_enabled = false

      visit "/admin/plugins/discourse-ai/ai-translations"

      expect(page).to have_css(".ai-translations__toggle-container .d-toggle-switch")
    end

    it "shows charts when translations are enabled" do
      SiteSetting.ai_translation_enabled = true
      SiteSetting.ai_translation_backfill_hourly_rate = 10

      visit "/admin/plugins/discourse-ai/ai-translations"

      expect(page).to have_css(".ai-translations__toggle-container")
      expect(page).to have_css(".ai-translations__charts")
    end

    it "hides charts when translations are disabled" do
      SiteSetting.ai_translation_enabled = false

      visit "/admin/plugins/discourse-ai/ai-translations"

      expect(page).to have_css(".ai-translations__toggle-container")
      expect(page).to have_no_css(".ai-translations__charts")
    end

    it "keeps toggle disabled when no locales are configured" do
      SiteSetting.ai_translation_enabled = false
      SiteSetting.content_localization_supported_locales = ""

      visit "/admin/plugins/discourse-ai/ai-translations"

      expect(page).to have_css(".d-toggle-switch__checkbox[disabled]")
    end
  end
end
