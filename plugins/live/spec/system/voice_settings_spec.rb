# frozen_string_literal: true

require_relative "../support/live_fake_media"

describe "Voice settings" do
  fab!(:user)
  fab!(:admin)
  fab!(:room) { Fabricate(:live_room, name: "Live Room", creator: admin, public: true) }

  before do
    user.activate
    SiteSetting.live_enabled = true
    SiteSetting.live_mesh_privacy_warning_enabled = false
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    sign_in(user)
    install_live_fake_media
  end

  def join_room
    visit("/live/r/#{room.slug}")
    click_button(I18n.t("js.live.room.join"))
    expect(page).to have_css(".live-room-page__leave")
  end

  def open_voice_settings
    find("button[data-identifier='live-audio-menu']").click
    within(".fk-d-menu[data-identifier='live-audio-menu']") do
      click_button(I18n.t("js.live.voice_settings.audio_settings"))
    end
    expect(page).to have_css(".live-voice-settings-modal")
  end

  it "offers the audio processing controls" do
    join_room
    open_voice_settings

    within(".live-voice-settings") do
      expect(page).to have_css(".live-voice-settings__noise-suppression-select")
      expect(page).to have_content(I18n.t("js.live.voice_settings.echo_cancellation"))
      expect(page).to have_content(I18n.t("js.live.voice_settings.auto_gain_control"))
    end
  end

  it "toggles echo cancellation and automatic gain control" do
    join_room
    open_voice_settings

    ec_toggle =
      PageObjects::Components::DToggleSwitch.new(".live-voice-settings__echo-cancellation-toggle")
    agc_toggle =
      PageObjects::Components::DToggleSwitch.new(".live-voice-settings__auto-gain-toggle")

    expect(ec_toggle.checked?).to eq(true)
    expect(agc_toggle.checked?).to eq(true)

    ec_toggle.toggle
    expect(ec_toggle.unchecked?).to eq(true)
    expect(agc_toggle.checked?).to eq(true)
  end

  # These run the real engine pipelines (wasm fetch, worklet ready
  # handshake), so the "AI" assertions only pass once the filter is genuinely
  # running — the modal spec covers DTLN, the submenu spec covers RNNoise.
  it "enables AI noise cancellation from the voice settings modal and shows the mic badge" do
    join_room
    open_voice_settings

    mode_select =
      PageObjects::Components::SelectKit.new(".live-voice-settings__noise-suppression-select")
    mode_select.expand
    mode_select.select_row_by_value("ai:dtln")

    expect(page).to have_css(".live-call-controls__ns-badge", wait: 15)
  end

  it "enables AI noise cancellation from the mic dropdown submenu" do
    join_room

    find("button[data-identifier='live-audio-menu']").click
    within(".fk-d-menu[data-identifier='live-audio-menu']") do
      click_button(I18n.t("js.live.voice_settings.noise_suppression"))
    end
    within(".fk-d-menu[data-identifier='live-call-submenu']") do
      click_button(I18n.t("js.live.voice_settings.noise_suppression_modes.ai_rnnoise"))
    end

    expect(page).to have_css(".live-call-controls__ns-badge", wait: 15)
  end
end
