# frozen_string_literal: true

describe "Admin Welcome Banner Config", type: :system do
  fab!(:admin)
  let(:config_page) { PageObjects::Pages::AdminWelcomeBannerConfig.new }

  before do
    sign_in(admin)
    SiteSetting.allow_user_locale = true
  end

  after do
    TranslationOverride.delete_all
    I18n.reload!
  end

  describe "locale selector" do
    it "displays a locale selector" do
      config_page.visit
      expect(config_page).to have_locale_selector
    end

    it "switches between locales and loads appropriate translations" do
      TranslationOverride.upsert!(
        "fr",
        "js.welcome_banner.header.new_members",
        "Bienvenue %{preferred_display_name}!",
      )
      TranslationOverride.upsert!("fr", "js.welcome_banner.search_placeholder", "Rechercher")

      config_page.visit

      expect(config_page.header_new_members_value).to eq("Welcome, %{preferred_display_name}!")
      expect(config_page.search_placeholder_value).to eq("Search")

      config_page.select_locale("fr")

      expect(config_page.header_new_members_value).to eq("Bienvenue %{preferred_display_name}!")
      expect(config_page.search_placeholder_value).to eq("Rechercher")
    end

    it "saves translations to the selected locale" do
      config_page.visit

      config_page.select_locale("fr")

      config_page.fill_header_new_members("Bonjour %{preferred_display_name}!")
      config_page.submit

      expect(config_page).to have_saved_message

      french_override =
        TranslationOverride.find_by(
          locale: "fr",
          translation_key: "js.welcome_banner.header.new_members",
        )
      expect(french_override.value).to eq("Bonjour %{preferred_display_name}!")

      config_page.visit
      expect(config_page.header_new_members_value).to eq("Welcome, %{preferred_display_name}!")
    end
  end
end
