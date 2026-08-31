# frozen_string_literal: true

require_relative "../support/voice_fake_media"

describe "Voice subtitles" do
  fab!(:user)
  fab!(:admin)
  fab!(:room) { Fabricate(:voice_room, name: "Voice Room", creator: admin, public: true) }

  before do
    user.activate
    SiteSetting.voice_enabled = true
    SiteSetting.voice_mesh_privacy_warning_enabled = false
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(user)
    install_voice_fake_media
  end

  def stub_webgpu
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.add_init_script(script: <<~JS)
        if (!navigator.gpu) {
          Object.defineProperty(navigator, "gpu", { configurable: true, value: {} });
        }
      JS
    end
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

  it "hides the subtitles toggle when the site setting is off" do
    SiteSetting.voice_subtitles_enabled = false
    stub_webgpu
    join_room
    open_voice_settings

    within(".voice-voice-settings") do
      expect(page).to have_no_content(I18n.t("js.voice.voice_settings.subtitles"))
    end
  end

  it "offers the subtitles toggle and enables the caption overlay" do
    SiteSetting.voice_subtitles_enabled = true
    stub_webgpu
    join_room
    open_voice_settings

    within(".voice-voice-settings") do
      expect(page).to have_content(I18n.t("js.voice.voice_settings.subtitles"))
    end

    toggle = PageObjects::Components::DToggleSwitch.new(".voice-voice-settings__subtitles-toggle")
    toggle.toggle
    expect(toggle.checked?).to eq(true)

    find(".modal-close").click
    expect(page).to have_css(".voice-captions", visible: :all)
  end
end
