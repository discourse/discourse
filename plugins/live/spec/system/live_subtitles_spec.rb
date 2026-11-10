# frozen_string_literal: true

require_relative "../support/live_fake_media"

describe "Live subtitles" do
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

  it "hides the subtitles toggle when the site setting is off" do
    SiteSetting.live_subtitles_enabled = false
    stub_webgpu
    join_room
    open_voice_settings

    within(".live-voice-settings") do
      expect(page).to have_no_content(I18n.t("js.live.voice_settings.subtitles"))
    end
  end

  it "offers the subtitles toggle and enables the caption overlay" do
    SiteSetting.live_subtitles_enabled = true
    stub_webgpu
    join_room
    open_voice_settings

    within(".live-voice-settings") do
      expect(page).to have_content(I18n.t("js.live.voice_settings.subtitles"))
    end

    toggle = PageObjects::Components::DToggleSwitch.new(".live-voice-settings__subtitles-toggle")
    toggle.toggle
    expect(toggle.checked?).to eq(true)

    find(".modal-close").click
    expect(page).to have_css(".live-captions", visible: :all)
  end

  it "lets the user pick the smaller subtitles model" do
    SiteSetting.live_subtitles_enabled = true
    stub_webgpu
    join_room
    open_voice_settings

    select = PageObjects::Components::SelectKit.new(".live-voice-settings__subtitles-model-select")
    expect(select).to have_selected_name(I18n.t("js.live.voice_settings.subtitles_models.ultra"))

    select.expand
    select.select_row_by_value("redux")

    expect(select).to have_selected_name(I18n.t("js.live.voice_settings.subtitles_models.redux"))
    expect(page.evaluate_script("localStorage.getItem('voice:stt-model')")).to eq("redux")
  end
end
