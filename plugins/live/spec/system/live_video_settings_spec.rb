# frozen_string_literal: true

require_relative "../support/live_fake_media"

describe "Live video settings" do
  fab!(:user)
  fab!(:admin)
  fab!(:room) { Fabricate(:live_room, name: "Video Room", creator: admin, public: true) }

  let(:camera_select) do
    PageObjects::Components::SelectKit.new(".live-video-settings__camera-select")
  end

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

  def open_video_menu
    find("button[data-identifier='live-video-menu']").click
    expect(page).to have_css(".fk-d-menu[data-identifier='live-video-menu']")
  end

  def open_video_settings
    open_video_menu
    within(".fk-d-menu[data-identifier='live-video-menu']") do
      click_button(I18n.t("js.live.video_settings.title"))
    end
    expect(page).to have_css(".live-video-settings-modal")
  end

  it "hides the screen share button from groups not allowed to share a screen" do
    SiteSetting.live_screen_share_allowed_groups = ""

    join_room

    expect(page).to have_button(I18n.t("js.live.video.camera_on"))
    expect(page).to have_no_button(I18n.t("js.live.video.screen_share_start"))
  end

  it "hides the camera button from groups not allowed to share a camera" do
    SiteSetting.live_video_allowed_groups = ""

    join_room

    expect(page).to have_button(I18n.t("js.live.video.screen_share_start"))
    expect(page).to have_no_button(I18n.t("js.live.video.camera_on"))
  end

  it "offers voice and video settings from the call menus" do
    join_room

    find("button[data-identifier='live-audio-menu']").click
    within(".fk-d-menu[data-identifier='live-audio-menu']") do
      expect(page).to have_button(I18n.t("js.live.voice_settings.audio_settings"))
    end
    find("button[data-identifier='live-audio-menu']").click

    open_video_menu
    within(".fk-d-menu[data-identifier='live-video-menu']") do
      expect(page).to have_button(I18n.t("js.live.video_settings.title"))
    end
  end

  it "shows a camera preview and lists camera devices" do
    join_room
    open_video_settings

    expect(page).to have_css(".live-video-settings__preview video")
    expect(live_media_track_live?(".live-video-settings__preview video")).to eq(true)

    camera_select.expand
    expect(camera_select).to have_option_name("Live fake camera A")
    expect(camera_select).to have_option_name("Live fake camera B")
  end

  it "keeps the published camera live after switching devices" do
    join_room
    click_button(I18n.t("js.live.video.camera_on"))

    video_selector =
      ".live-video-tile.--video[data-user-id='#{user.id}'] video.live-video-tile__video"
    expect(page).to have_css(video_selector)

    open_video_settings
    camera_select.expand
    camera_select.select_row_by_name("Live fake camera B")

    expect(camera_select).to have_selected_name("Live fake camera B")
    expect(live_media_track_live?(video_selector)).to eq(true)
  end

  it "shows the background blur toggle when the setting is enabled" do
    join_room
    open_video_settings

    within(".live-video-settings") { expect(page).to have_css(".d-toggle-switch") }
  end

  it "hides background blur when the site setting is disabled" do
    SiteSetting.live_video_background_blur_enabled = false

    join_room
    open_video_settings

    within(".live-video-settings") do
      expect(page).to have_css(".live-video-settings__camera-select")
      expect(page).to have_no_css(".d-toggle-switch")
    end
  end
end
