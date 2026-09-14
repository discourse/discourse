# frozen_string_literal: true

describe "Configure a LiveKit agent" do
  fab!(:admin)
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://test.livekit.cloud"
    SiteSetting.voice_livekit_api_key = "key"
    SiteSetting.voice_livekit_api_secret = "secret"
    sign_in(admin)
  end

  it "lets an admin enable the bot without configuring an agent name" do
    settings_page.visit("voice_livekit_agent")
    expect(settings_page).to have_setting("voice_livekit_agent_enabled")
    expect(page).to have_content("Voice livekit agent enabled")
    expect(page).to have_content(I18n.t("site_settings.voice_livekit_agent_enabled"))

    settings_page.toggle_bool_setting("voice_livekit_agent_enabled")

    page.refresh
    expect(settings_page.bool_setting_checkbox("voice_livekit_agent_enabled")).to be_checked
  end
end
