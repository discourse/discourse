# frozen_string_literal: true

describe "Admin Site Setting Locales", type: :system do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  fab!(:admin)

  before do
    sign_in(admin)
    SiteSetting.default_locale = "es"
    SiteSetting.content_localization_supported_locales = "es|en"
  end

  context "for locale enum" do
    it "allows selection of a different locale" do
      settings_page.visit

      settings_page.type_in_search("default locale")
      expect(settings_page.find_setting("default_locale")).to have_content("Español")

      settings_page.select_enum_value("default_locale", "en")
      settings_page.save_setting("default_locale")

      settings_page.type_in_search("default locale")
      expect(settings_page.find_setting("default_locale")).to have_content(
        "Inglés (EE. UU.) (English (US))",
      )
    end
  end

  context "for locale lists" do
    it "allows adding and removing locales" do
      SiteSetting.content_localization_supported_locales = "ja"
      sign_in(admin)

      settings_page.visit("content_localization_supported_locales")
      expect(settings_page.find_setting("content_localization_supported_locales")).to have_content(
        "Japonés (日本語)",
      )

      settings_page.select_list_values("content_localization_supported_locales", %w[en])
      settings_page.save_setting("content_localization_supported_locales")
      expect(settings_page.find_setting("content_localization_supported_locales")).to have_content(
        "Japonés (日本語), Inglés (EE. UU.)",
      )

      # confirm persist on reload
      settings_page.visit("content_localization_supported_locales")
      expect(settings_page.find_setting("content_localization_supported_locales")).to have_content(
        "Japonés (日本語), Inglés (EE. UU.)",
      )
    end
  end
end
