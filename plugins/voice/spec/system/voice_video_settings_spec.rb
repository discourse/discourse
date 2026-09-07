# frozen_string_literal: true

require_relative "../support/voice_fake_media"

describe "Voice video settings" do
  fab!(:user)
  fab!(:admin)
  fab!(:room) { Fabricate(:voice_room, name: "Video Room", creator: admin, public: true) }

  let(:camera_select) do
    PageObjects::Components::SelectKit.new(".voice-video-settings__camera-select")
  end

  before do
    user.activate
    SiteSetting.voice_enabled = true
    SiteSetting.voice_mesh_privacy_warning_enabled = false
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.voice_video_enabled = true
    sign_in(user)
    install_voice_fake_media
  end

  def join_room
    visit("/voice/r/#{room.slug}")
    click_button(I18n.t("js.voice.room.join"))
    expect(page).to have_css(".voice-room-page__leave")
  end

  def open_video_menu
    find("button[data-identifier='voice-video-menu']").click
    expect(page).to have_css(".fk-d-menu[data-identifier='voice-video-menu']")
  end

  def open_video_settings
    open_video_menu
    within(".fk-d-menu[data-identifier='voice-video-menu']") do
      click_button(I18n.t("js.voice.video_settings.title"))
    end
    expect(page).to have_css(".voice-video-settings-modal")
  end

  it "offers voice and video settings from the call menus" do
    join_room

    find("button[data-identifier='voice-audio-menu']").click
    within(".fk-d-menu[data-identifier='voice-audio-menu']") do
      expect(page).to have_button(I18n.t("js.voice.voice_settings.audio_settings"))
    end
    find("button[data-identifier='voice-audio-menu']").click

    open_video_menu
    within(".fk-d-menu[data-identifier='voice-video-menu']") do
      expect(page).to have_button(I18n.t("js.voice.video_settings.title"))
    end
  end

  it "shows a camera preview and lists camera devices" do
    join_room
    open_video_settings

    expect(page).to have_css(".voice-video-settings__preview video")
    expect(voice_media_track_live?(".voice-video-settings__preview video")).to eq(true)

    camera_select.expand
    expect(camera_select).to have_option_name("Voice fake camera A")
    expect(camera_select).to have_option_name("Voice fake camera B")
  end

  it "keeps the published camera live after switching devices" do
    join_room
    click_button(I18n.t("js.voice.video.camera_on"))

    video_selector =
      ".voice-video-tile.--video[data-user-id='#{user.id}'] video.voice-video-tile__video"
    expect(page).to have_css(video_selector)

    open_video_settings
    camera_select.expand
    camera_select.select_row_by_name("Voice fake camera B")

    expect(camera_select).to have_selected_name("Voice fake camera B")
    expect(voice_media_track_live?(video_selector)).to eq(true)
  end

  it "shows the background blur toggle when the setting is enabled" do
    join_room
    open_video_settings

    within(".voice-video-settings") { expect(page).to have_css(".d-toggle-switch") }
  end

  it "hides background blur when the site setting is disabled" do
    SiteSetting.voice_video_background_blur_enabled = false

    join_room
    open_video_settings

    within(".voice-video-settings") do
      expect(page).to have_css(".voice-video-settings__camera-select")
      expect(page).to have_no_css(".d-toggle-switch")
    end
  end
end
