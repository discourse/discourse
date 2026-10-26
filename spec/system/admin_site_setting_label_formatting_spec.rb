# frozen_string_literal: true

describe "Admin Site Setting Formatting" do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  fab!(:admin)

  before { sign_in(admin) }

  it "formats capitalization, acronyms and combined replacements in setting headings" do
    setting_name = "default_locale"
    settings_page.visit(setting_name)
    expect(setting_label(setting_name)).to eq("Default locale")

    settings_page.clear_search
    setting_name = "faq_url"
    settings_page.type_in_search(setting_name)
    expect(setting_label(setting_name)).to eq("FAQ URL")

    settings_page.clear_search
    setting_name = "enable_discourse_connect"
    settings_page.type_in_search(setting_name)
    expect(setting_label(setting_name)).to eq("Enable Discourse Connect")

    settings_page.clear_search
    setting_name = "google_oauth2_client_id"
    settings_page.type_in_search(setting_name)
    expect(setting_label(setting_name)).to eq("Google OAuth2 client ID")
  end

  def setting_label(setting_name)
    settings_page.find(settings_page.setting_row_selector(setting_name) + " h3").text
  end
end
