# frozen_string_literal: true

describe "Admin Site Setting Formatting", type: :system do
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  fab!(:admin)

  before { sign_in(admin) }

  it "capitalises the first letter of labels" do
    setting_name = "default_locale"

    settings_page.visit(setting_name)

    expect(setting_label(setting_name)).to eq("Default locale")
  end

  it "capitalises acronyms in labels" do
    setting_name = "faq_url"

    settings_page.visit(setting_name)

    expect(setting_label(setting_name)).to eq("FAQ URL")
  end

  it "matches multi-word replacements" do
    setting_name = "enable_discourse_connect"

    settings_page.visit(setting_name)

    expect(setting_label(setting_name)).to eq("Enable Discourse Connect")
  end

  it "matches multiple types of replacements" do
    setting_name = "google_oauth2_client_id"

    settings_page.visit(setting_name)

    expect(setting_label(setting_name)).to eq("Google OAuth2 client ID")
  end

  def setting_label(setting_name)
    settings_page.find(settings_page.setting_row_selector(setting_name) + " h3").text
  end
end
