# frozen_string_literal: true

describe "Admin AI translations" do
  fab!(:admin)
  let(:translations_page) { PageObjects::Pages::AdminAiTranslations.new }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)

    allow(DiscourseAi::Translation).to receive(:has_llm_model?).and_return(true)
    allow(DiscourseAi::Translation::Progress).to receive(:fetch).and_return(
      {
        targets: [
          {
            target_type: "post",
            total_count: 474,
            translated_count: 215,
            needs_language_detection_count: 93,
          },
          {
            target_type: "topic",
            total_count: 86,
            translated_count: 51,
            needs_language_detection_count: 12,
          },
          {
            target_type: "category",
            total_count: 18,
            translated_count: 18,
            needs_language_detection_count: 0,
          },
          {
            target_type: "tag",
            total_count: 142,
            translated_count: 64,
            needs_language_detection_count: 7,
          },
        ],
        cached_at: Time.now.utc.iso8601,
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

    it "displays the translations page with model progress cards" do
      expect(translations_page).to have_translations_page
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.title"))
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.description"))

      expect(translations_page).to have_translation_settings_button
      expect(translations_page).to have_localization_settings_button
      expect(page).to have_css(
        ".ai-translation-settings-button",
        text: I18n.t("js.discourse_ai.translations.admin_actions.translation_settings"),
      )
      expect(page).to have_css(
        ".ai-localization-settings-button",
        text: I18n.t("js.discourse_ai.translations.admin_actions.localization_settings"),
      )
      expect(page).to have_css(".ai-translations__locale-input-row .multi-select")
      expect(page).to have_css(".ai-translations__category-input-row .combo-box")
      expect(page).to have_css(
        ".ai-translations__settings-panel > .setting:first-child .d-toggle-switch",
      )
      expect(page).to have_no_css(".ai-translations__settings-panel.alert-info")

      expect(translations_page).to have_overview_cards
      expect(page).to have_no_css(".ai-translations__overview .admin-config-area-card")
      expect(page).to have_css(
        ".ai-translations__cached-results",
        text: "Showing cached results from",
      )
      expect(page).to have_no_content("estimated to take")
      expect(page).to have_css(
        ".ai-translation-model-progress-overview-card__headline",
        text: "All 18 eligible categories are fully translated.",
      )
      expect(page).to have_css(
        ".ai-translation-model-progress-overview-card__headline",
        text: "There are 142 tags for translation.",
      )

      screenshot_marker(label: "ai-admin-translations", only: "desktop")
    end

    it "navigates to translation settings when clicking the settings button" do
      translation_id = DiscourseAi::Configuration::Module::TRANSLATION_ID
      find(".ai-translation-settings-button").click

      expect(page).to have_current_path(
        "/admin/plugins/discourse-ai/ai-features/#{translation_id}/edit",
      )
    end

    it "navigates to app language settings when clicking the app language button" do
      find(".ai-localization-settings-button").click

      expect(page).to have_current_path("/admin/config/localization")
    end

    it "toggles the selected target for the upcoming details panel" do
      translations_page.toggle_target("post")
      expect(translations_page).to have_expanded_target("post")

      translations_page.toggle_target("post")
      expect(translations_page).to have_no_expanded_target
    end
  end

  describe "when translations are disabled" do
    fab!(:category)

    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_translation_enabled = false
      SiteSetting.content_localization_supported_locales = "en|fr|es"
      SiteSetting.ai_translation_category_scope = "include"
      SiteSetting.ai_translation_categories = category.id.to_s
      SiteSetting.ai_translation_backfill_max_age_days = 30

      translations_page.visit
    end

    it "shows the toggle in off state and no progress cards" do
      expect(translations_page).to have_toggle

      expect(translations_page).to have_no_overview_cards
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

    it "displays the settings panel with locale selector" do
      expect(translations_page).to have_locale_selector
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.supported_locales"))
    end

    it "displays the category scope selector alongside the locale selector" do
      expect(page).to have_css(".ai-translations__settings-panel")
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.category_scope"))
      expect(page).to have_css(".ai-translations__category-input-row .combo-box")
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

  describe "when selected categories are configured" do
    fab!(:category)

    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_translation_enabled = false
      SiteSetting.content_localization_supported_locales = "en|fr"
      SiteSetting.ai_translation_category_scope = "include"
      SiteSetting.ai_translation_categories = ""
      SiteSetting.ai_translation_backfill_max_age_days = 30

      visit "/admin/plugins/discourse-ai/ai-translations"
    end

    it "displays the settings panel with the category selector" do
      expect(page).to have_css(".ai-translations__settings-panel")
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.category_scope"))
      expect(page).to have_css(".category-selector")
    end

    it "allows adding and saving selected categories" do
      find(".category-selector").click
      find(".category-row[data-value='#{category.id}']").click

      within(".ai-translations__category-input-row") { find(".setting-controls__ok").click }

      expect(page).to have_no_css(".ai-translations__category-input-row .setting-controls__ok")
      expect(SiteSetting.ai_translation_category_scope).to eq("include")
      expect(SiteSetting.ai_translation_categories).to eq(category.id.to_s)
    end
  end

  describe "translation toggle" do
    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.content_localization_supported_locales = "en|fr"
      SiteSetting.ai_translation_backfill_max_age_days = 30
    end

    it "displays the translation toggle" do
      SiteSetting.ai_translation_enabled = false

      translations_page.visit

      expect(translations_page).to have_toggle
    end

    it "shows progress cards when translations are enabled" do
      SiteSetting.ai_translation_enabled = true
      SiteSetting.ai_translation_backfill_hourly_rate = 10

      translations_page.visit

      expect(translations_page).to have_toggle
      expect(translations_page).to have_overview_cards
    end

    it "hides progress cards when translations are disabled" do
      SiteSetting.ai_translation_enabled = false

      translations_page.visit

      expect(translations_page).to have_toggle
      expect(translations_page).to have_no_overview_cards
    end

    it "keeps toggle disabled when no locales are configured" do
      SiteSetting.ai_translation_enabled = false
      SiteSetting.content_localization_supported_locales = ""

      translations_page.visit

      expect(translations_page).to have_toggle_disabled
    end
  end
end
