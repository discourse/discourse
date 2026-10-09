# frozen_string_literal: true

require_relative "../support/voice_fake_media"

describe "Voice settings" do
  fab!(:user)
  fab!(:admin)
  fab!(:room) { Fabricate(:voice_room, name: "Voice Room", creator: admin, public: true) }

  before do
    user.activate
    SiteSetting.voice_enabled = true
    SiteSetting.voice_mesh_privacy_warning_enabled = false
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    sign_in(user)
    install_voice_fake_media
  end

  def join_room
    visit("/voice/r/#{room.slug}")
    click_button(I18n.t("js.voice.room.join"))
    expect(page).to have_css(".voice-room-page__leave")
  end

  def open_voice_settings
    find("button[data-identifier='voice-audio-menu']").click
    within(".fk-d-menu[data-identifier='voice-audio-menu']") do
      click_button(I18n.t("js.voice.voice_settings.audio_settings"))
    end
    expect(page).to have_css(".voice-voice-settings-modal")
  end

  it "offers the audio processing controls" do
    join_room
    open_voice_settings

    within(".voice-voice-settings") do
      expect(page).to have_css(".voice-voice-settings__noise-suppression-select")
      expect(page).to have_content(I18n.t("js.voice.voice_settings.echo_cancellation"))
      expect(page).to have_content(I18n.t("js.voice.voice_settings.auto_gain_control"))
    end
  end

  it "toggles echo cancellation and automatic gain control" do
    join_room
    open_voice_settings

    ec_toggle =
      PageObjects::Components::DToggleSwitch.new(".voice-voice-settings__echo-cancellation-toggle")
    agc_toggle =
      PageObjects::Components::DToggleSwitch.new(".voice-voice-settings__auto-gain-toggle")

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
      PageObjects::Components::SelectKit.new(".voice-voice-settings__noise-suppression-select")
    mode_select.expand
    mode_select.select_row_by_value("ai:dtln")

    expect(page).to have_css(".voice-call-controls__ns-badge", wait: 15)
  end

  it "enables AI noise cancellation from the mic dropdown submenu" do
    join_room

    find("button[data-identifier='voice-audio-menu']").click
    within(".fk-d-menu[data-identifier='voice-audio-menu']") do
      click_button(I18n.t("js.voice.voice_settings.noise_suppression"))
    end
    within(".fk-d-menu[data-identifier='voice-call-submenu']") do
      click_button(I18n.t("js.voice.voice_settings.noise_suppression_modes.ai_rnnoise"))
    end

    expect(page).to have_css(".voice-call-controls__ns-badge", wait: 15)
  end
end
