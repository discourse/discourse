# frozen_string_literal: true

RSpec.describe "Admin AI translations" do
  fab!(:admin)
  let(:translations_page) { PageObjects::Pages::AdminAiTranslations.new }

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

      translations_page.visit
    end

    it "displays the translations page with chart" do
      expect(translations_page).to have_translations_page
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.title"))
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.description"))

      expect(translations_page).to have_translation_settings_button
      expect(translations_page).to have_localization_settings_button

      expect(translations_page).to have_charts_section
      expect(translations_page).to have_chart

      screenshot_marker(label: "ai-admin-translations", only: "desktop")
    end

    it "navigates to translation settings when clicking the settings button" do
      translation_id = DiscourseAi::Configuration::Module::TRANSLATION_ID
      find(".ai-translation-settings-button").click

      expect(page).to have_current_path(
        "/admin/plugins/discourse-ai/ai-features/#{translation_id}/edit",
      )
    end

    it "navigates to localization settings when clicking the localization button" do
      find(".ai-localization-settings-button").click

      expect(page).to have_current_path("/admin/config/localization")
    end
  end

  describe "when translations are disabled" do
    fab!(:category)

    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_translation_enabled = false
      SiteSetting.content_localization_supported_locales = "en|fr|es"
      SiteSetting.ai_translation_target_categories = category.id.to_s
      SiteSetting.ai_translation_backfill_max_age_days = 30

      translations_page.visit
    end

    it "shows the toggle in off state and no chart" do
      expect(translations_page).to have_toggle

      expect(translations_page).to have_no_chart
    end

    it "shows localization settings button" do
      expect(translations_page).to have_localization_settings_button
    end

    it "keeps language and category selectors visible" do
      expect(page).to have_css(".ai-translations__locale-input-row .multi-select")
      expect(page).to have_css(".ai-translations__category-input-row .category-selector")
    end
  end

  describe "when locales are not configured" do
    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_translation_enabled = false
      SiteSetting.content_localization_supported_locales = ""
      SiteSetting.ai_translation_backfill_max_age_days = 30

      translations_page.visit
    end

    it "displays the alert with locale selector" do
      expect(translations_page).to have_locale_selector
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.supported_locales"))
    end

    it "displays the category selector alongside the locale selector" do
      expect(page).to have_css(".alert.alert-info")
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.translatable_categories"))
      expect(page).to have_css(".category-selector")
    end

    it "allows adding and saving languages" do
      within(".ai-translations__locale-input-row") do
        find(".multi-select").click
        find(".select-kit-row[data-value='en']").click
        find(".setting-controls__ok").click
      end

      expect(page).to have_no_css(".ai-translations__locale-input-row .setting-controls__ok")

      expect(SiteSetting.content_localization_supported_locales).to eq("en")
    end
  end

  describe "when categories are not configured" do
    fab!(:category)

    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_translation_enabled = false
      SiteSetting.content_localization_supported_locales = "en|fr"
      SiteSetting.ai_translation_target_categories = ""
      SiteSetting.ai_translation_backfill_max_age_days = 30

      visit "/admin/plugins/discourse-ai/ai-translations"
    end

    it "displays the setup alert with the category selector" do
      expect(page).to have_css(".alert.alert-info")
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.translatable_categories"))
      expect(page).to have_css(".category-selector")
    end

    it "allows adding and saving translatable categories" do
      find(".category-selector").click
      find(".category-row[data-value='#{category.id}']").click

      within(".ai-translations__category-input-row") { find(".setting-controls__ok").click }

      expect(page).to have_no_css(".ai-translations__category-input-row .setting-controls__ok")
      expect(SiteSetting.ai_translation_target_categories).to eq(category.id.to_s)
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

      translations_page.visit

      expect(translations_page).to have_toggle
    end

    it "shows charts when translations are enabled" do
      SiteSetting.ai_translation_enabled = true
      SiteSetting.ai_translation_backfill_hourly_rate = 10

      translations_page.visit

      expect(translations_page).to have_toggle
      expect(translations_page).to have_charts_section
    end

    it "hides charts when translations are disabled" do
      SiteSetting.ai_translation_enabled = false

      translations_page.visit

      expect(translations_page).to have_toggle
      expect(translations_page).to have_no_chart
    end

    it "keeps toggle disabled when no locales are configured" do
      SiteSetting.ai_translation_enabled = false
      SiteSetting.content_localization_supported_locales = ""

      translations_page.visit

      expect(translations_page).to have_toggle_disabled
    end
  end
end
