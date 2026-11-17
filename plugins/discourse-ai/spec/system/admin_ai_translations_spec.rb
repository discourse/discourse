# frozen_string_literal: true

describe "Admin AI translations" do
  fab!(:admin)
  let(:translations_page) { PageObjects::Pages::AdminAiTranslations.new }
  let(:form) { PageObjects::Components::FormKit.new(".ai-translations__settings-panel") }
  let(:toasts) { PageObjects::Components::Toasts.new }

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
    allow(DiscourseAi::Translation::Progress).to receive(:fetch_detail) do |target_type|
      denominator_key = target_type == "tag" ? :total_count : :eligible_count
      {
        target_type:,
        cached_at: Time.now.utc.iso8601,
        locales: [
          { :locale => "en", :translated_count => 30, :pending_count => 20, denominator_key => 50 },
        ],
      }
    end

    sign_in(admin)
  end

  describe "when translations are enabled" do
    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_translation_enabled = true
      SiteSetting.content_localization_enabled = false
      SiteSetting.content_localization_supported_locales = "en|fr|es"
      SiteSetting.ai_translation_backfill_hourly_rate = 10

      translations_page.visit
    end

    it "displays the translations page with model progress cards" do
      expect(translations_page).to have_translations_page
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.title"))
      expect(page).to have_content(I18n.t("js.discourse_ai.translations.description"))

      expect(translations_page).to have_locale_selector
      expect(translations_page).to have_toggle
      expect(page).to have_css(".ai-translations__readers-notice")
      expect(page).to have_css(
        ".ai-translations__more-settings",
        text: I18n.t("js.discourse_ai.translations.more_language_settings"),
      )
      expect(page).to have_css(
        ".form-kit__section-title",
        text: I18n.t("js.discourse_ai.translations.sections.backfill"),
      )
      expect(page).to have_no_css(".ai-translations__agents[open]")
      find(".ai-translations__agents summary").click
      expect(form.field("ai_translation_locale_detector_agent")).to be_enabled

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

    it "links to the remaining core language settings" do
      find(".ai-translations__more-settings").click
      expect(page).to have_current_path("/admin/config/localization")
    end

    it "toggles the selected target for the upcoming details panel" do
      translations_page.toggle_target("post")
      expect(translations_page).to have_expanded_target("post")

      translations_page.toggle_target("post")
      expect(translations_page).to have_no_expanded_target
    end

    it "loads and reuses per-target locale details when a card is expanded" do
      translations_page.toggle_target("post")

      expect(translations_page).to have_detail_table
      expect(translations_page).to have_detail_row(
        locale: "en",
        translated: 30,
        pending: 20,
        denominator: 50,
      )

      translations_page.toggle_target("post")
      expect(translations_page).to have_no_detail_table

      translations_page.toggle_target("post")
      expect(translations_page).to have_detail_table
      expect(DiscourseAi::Translation::Progress).to have_received(:fetch_detail).with("post").once
    end

    it "reloads expanded details after category settings change" do
      translations_page.toggle_target("post")
      expect(translations_page).to have_detail_table

      form.field("ai_translation_category_scope").select("all")
      form.submit
      expect(toasts).to have_success(I18n.t("js.saved"))

      expect(translations_page).to have_detail_table
      expect(DiscourseAi::Translation::Progress).to have_received(:fetch_detail).with("post").twice
    end
  end

  it "saves languages without enabling generation or reader visibility" do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = false
    SiteSetting.content_localization_enabled = false
    SiteSetting.content_localization_supported_locales = ""

    translations_page.visit
    expect(translations_page).to have_toggle_disabled
    expect(page).to have_css(
      ".ai-translations__toggle-hint",
      text: I18n.t("js.discourse_ai.translations.admin_actions.enable_translations_disabled"),
    )
    form.field("content_localization_supported_locales").select("English")
    expect(translations_page).to have_toggle_disabled
    form.submit
    expect(toasts).to have_success(I18n.t("js.saved"))

    page.refresh
    expect(form.field("content_localization_supported_locales")).to have_value("en")
    expect(form.field("content_localization_enabled")).to be_unchecked
    expect(translations_page).to have_toggle_off
    expect(translations_page).to have_no_toggle_disabled
  end

  it "saves category scope, selected categories, and backfill in the same form" do
    category = Fabricate(:category)
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = false
    SiteSetting.content_localization_supported_locales = "en|fr"
    SiteSetting.ai_translation_category_scope = "public"

    translations_page.visit
    expect(page).to have_no_css("[data-name='ai_translation_categories']")
    form.field("ai_translation_category_scope").select("include")
    find(".category-selector").click
    find(".category-row[data-value='#{category.id}']").click
    find(".category-selector .select-kit-header").click
    form.field("ai_translation_backfill_hourly_rate").fill_in(75)
    form.submit
    expect(toasts).to have_success(I18n.t("js.saved"))

    page.refresh
    expect(form.field("ai_translation_category_scope")).to have_value("include")
    expect(page).to have_css(".category-selector .select-kit-header", text: category.name)
    expect(form.field("ai_translation_backfill_hourly_rate")).to have_value("75")
  end

  it "controls generation independently from readers" do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = false
    SiteSetting.content_localization_supported_locales = "en|fr"
    SiteSetting.content_localization_enabled = false
    SiteSetting.content_localization_language_switcher = "none"

    translations_page.visit
    translations_page.toggle_translations
    expect(translations_page).to have_toggle_on
    expect(page).to have_css(".ai-translations__readers-notice a[href='#ai-translations-readers']")
    expect(form.field("content_localization_enabled")).to be_unchecked
    expect(form.field("content_localization_language_switcher")).to have_value("none")

    form.field("content_localization_enabled").check
    form.submit
    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(page).to have_no_css(".ai-translations__readers-notice")

    translations_page.toggle_translations
    expect(translations_page).to have_toggle_off
    page.refresh
    expect(form.field("content_localization_enabled")).to be_checked
    expect(form.field("content_localization_language_switcher")).to have_value("none")
    expect(translations_page).to have_toggle_off
  end

  it "allows disabling generation when no languages are configured" do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_translation_enabled = true
    SiteSetting.content_localization_supported_locales = ""

    translations_page.visit
    expect(translations_page).to have_toggle_on
    translations_page.toggle_translations
    expect(translations_page).to have_toggle_off
    expect(translations_page).to have_toggle_disabled
  end
end
