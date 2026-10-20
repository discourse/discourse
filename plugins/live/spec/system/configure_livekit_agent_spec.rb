# frozen_string_literal: true

describe "Configure a LiveKit agent" do
  fab!(:admin)
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_livekit_url = "wss://test.livekit.cloud"
    SiteSetting.live_livekit_api_key = "key"
    SiteSetting.live_livekit_api_secret = "secret"
    sign_in(admin)
  end

  it "lets an admin enable the bot without configuring an agent name" do
    settings_page.visit("live_livekit_agent")
    expect(settings_page).to have_setting("live_livekit_agent_enabled")
    expect(settings_page).to have_setting("live_livekit_agent_invite_allowed_groups")
    expect(page).to have_content("Live livekit agent enabled")
    # The description embeds a {{setting:...}} token that renders as a link,
    # so only a token-free fragment can be matched literally.
    expect(page).to have_content("to invite a LiveKit Cloud agent to public live rooms")

    settings_page.toggle_bool_setting("live_livekit_agent_enabled")

    page.refresh
    expect(settings_page.bool_setting_checkbox("live_livekit_agent_enabled")).to be_checked
  end
end
