# frozen_string_literal: true

require_relative "page_objects/components/voice_sidebar"
require_relative "../support/voice_fake_media"

describe "Voice rooms" do
  let(:voice_sidebar) { PageObjects::Components::VoiceSidebar.new }

  def click_room_page_widget_mode_button
    find("button[data-identifier='voice-room-menu']").click
    within(".fk-d-menu[data-identifier='voice-room-menu']") do
      click_button(I18n.t("js.voice.room.widget_mode"))
    end
  end

  def click_call_widget_open_page_button
    within(".voice-call-widget__controls") { find(".d-icon-expand").ancestor("button").click }
  end

  def click_call_widget_leave_button
    within(".voice-call-widget__controls") { find(".voice-call-widget__leave").click }
  end

  def switch_layout(layout_label)
    find("button[data-identifier='voice-room-menu']").click
    within(".fk-d-menu[data-identifier='voice-room-menu']") do
      click_button(I18n.t("js.voice.room.layout"))
    end
    click_button(layout_label)
  end

  fab!(:user)
  fab!(:other_user, :user)
  fab!(:admin)

  before do
    user.activate
    SiteSetting.voice_enabled = true
    SiteSetting.voice_mesh_privacy_warning_enabled = false
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.voice_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
  end

  context "when plugin is disabled" do
    it "does not show voice rooms section" do
      SiteSetting.voice_enabled = false
      Fabricate(:voice_room, name: "Test Room", creator: admin, public: true)
      sign_in(user)

      visit("/latest")

      expect(voice_sidebar).to be_not_visible
    end
  end

  context "when plugin is enabled" do
    context "as anonymous user" do
      it "shows public rooms when access is open to everyone" do
        Fabricate(:voice_room, name: "Test Room", creator: admin, public: true)

        visit("/latest")

        expect(voice_sidebar).to be_visible
      end

      it "does not show voice rooms section when access is restricted to a group" do
        SiteSetting.voice_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
        Fabricate(:voice_room, name: "Test Room", creator: admin, public: true)

        visit("/latest")

        expect(voice_sidebar).to be_not_visible
      end
    end

    context "as logged in user" do
      fab!(:room) { Fabricate(:voice_room, name: "Test Room", creator: admin, public: true) }

      before do
        user.update!(trust_level: TrustLevel[2])
        Group.refresh_automatic_groups!
        sign_in(user)
      end

      it "shows voice rooms section when rooms exist" do
        visit("/latest")

        expect(voice_sidebar).to be_visible
      end

      it "displays public rooms in the sidebar" do
        visit("/latest")

        expect(voice_sidebar).to be_visible
        expect(voice_sidebar).to have_room(room.name)
      end

      it "hides private rooms from non-members even when they can create rooms" do
        private_room = Fabricate(:voice_room, name: "Private Room", creator: admin, public: false)

        visit("/latest")

        expect(voice_sidebar).to have_room(room.name)
        expect(voice_sidebar).to have_no_room(private_room.name)
      end

      it "shows private rooms to their members" do
        private_room = Fabricate(:voice_room, name: "Private Room", creator: admin, public: false)
        private_room.room_memberships.create!(user: user)

        visit("/latest")

        expect(voice_sidebar).to have_room(private_room.name)
      end

      it "can publish a fake camera stream on the room page" do
        SiteSetting.voice_video_enabled = true
        install_voice_fake_media

        visit("/voice/r/#{room.slug}")
        click_button(I18n.t("js.voice.room.join"))

        expect(page).to have_button(I18n.t("js.voice.video.camera_on"))
        click_button(I18n.t("js.voice.video.camera_on"))

        video_selector =
          ".voice-video-tile.--video[data-user-id='#{user.id}'] video.voice-video-tile__video"
        expect(page).to have_css(video_selector)
        expect(voice_media_track_count(video_selector)).to eq(1)
      end

      it "switches between presentation and tiled layouts from the menu" do
        SiteSetting.voice_video_enabled = true
        install_voice_fake_media

        visit("/voice/r/#{room.slug}")
        click_button(I18n.t("js.voice.room.join"))
        expect(page).to have_css(".voice-room-page__leave")
        expect(page).to have_css(".voice-room-page.--tiled")

        switch_layout(I18n.t("js.voice.video.layout_presentation"))
        expect(page).to have_css(".voice-room-page.--presentation")

        switch_layout(I18n.t("js.voice.video.layout_tiled"))
        expect(page).to have_css(".voice-room-page.--tiled")
      end

      it "keeps the active call in a widget after switching to widget mode" do
        SiteSetting.voice_video_enabled = true
        install_voice_fake_media

        visit("/voice/r/#{room.slug}")
        click_button(I18n.t("js.voice.room.join"))
        click_button(I18n.t("js.voice.video.camera_on"))

        click_room_page_widget_mode_button

        expect(page).to have_css(".voice-call-widget", text: room.name)
        expect(page).to have_button(I18n.t("js.voice.video.camera_off"))

        widget_video_selector =
          ".voice-call-widget .voice-video-tile.--video[data-user-id='#{user.id}'] video.voice-video-tile__video"
        expect(page).to have_css(widget_video_selector)
        expect(voice_media_track_count(widget_video_selector)).to eq(1)

        click_call_widget_open_page_button

        page_video_selector =
          ".voice-room-page .voice-video-tile.--video[data-user-id='#{user.id}'] video.voice-video-tile__video"
        expect(page).to have_current_path("/voice/r/#{room.slug}")
        expect(page).to have_css(page_video_selector)
        expect(voice_media_track_count(page_video_selector)).to eq(1)
      end

      it "can stop video and leave the call from the persistent widget" do
        SiteSetting.voice_video_enabled = true
        install_voice_fake_media

        visit("/voice/r/#{room.slug}")
        click_button(I18n.t("js.voice.room.join"))
        click_button(I18n.t("js.voice.video.camera_on"))

        click_room_page_widget_mode_button

        within(".voice-call-widget") { click_button(I18n.t("js.voice.video.camera_off")) }

        expect(page).to have_button(I18n.t("js.voice.video.camera_on"))
        expect(page).to have_no_css(".voice-call-widget .voice-video-tile.--video")

        click_call_widget_leave_button

        expect(page).to have_no_css(".voice-call-widget")
      end

      it "opens room actions from the widget overflow menu" do
        SiteSetting.voice_video_enabled = true
        install_voice_fake_media

        visit("/voice/r/#{room.slug}")
        click_button(I18n.t("js.voice.room.join"))
        click_room_page_widget_mode_button

        expect(page).to have_css(".voice-call-widget", text: room.name)

        # The overflow menu portals out at the dropdown z-index; opening it and
        # clicking an item asserts it renders above the widget rather than
        # behind it.
        find(".voice-call-widget button[data-identifier='voice-widget-room-menu']").click
        within(".fk-d-menu[data-identifier='voice-widget-room-menu']") do
          click_button(I18n.t("js.voice.room.info"))
        end

        expect(page).to have_css(".voice-room-info-modal")
      end

      it "shows remote fake video when another user publishes a camera stream" do
        SiteSetting.voice_video_enabled = true
        other_user.activate
        other_user.update!(trust_level: TrustLevel[2])
        Group.refresh_automatic_groups!

        using_session(:alice) do
          sign_in(user)
          install_voice_fake_media(
            video_feeds: [
              {
                label: "Alice fake camera",
                width: 640,
                height: 360,
                color: "#2563eb",
                accent: "#f97316",
              },
            ],
          )
          visit("/voice/r/#{room.slug}")
          click_button(I18n.t("js.voice.room.join"))
          expect(page).to have_button(I18n.t("js.voice.video.camera_on"))
        end

        using_session(:bob) do
          sign_in(other_user)
          install_voice_fake_media(
            video_feeds: [
              {
                label: "Bob fake camera",
                width: 640,
                height: 360,
                color: "#16a34a",
                accent: "#7c3aed",
              },
            ],
          )
          visit("/voice/r/#{room.slug}")
          click_button(I18n.t("js.voice.room.join"))
          click_button(I18n.t("js.voice.video.camera_on"))

          local_video_selector =
            ".voice-video-tile.--video[data-user-id='#{other_user.id}'] video.voice-video-tile__video"
          expect(page).to have_css(local_video_selector)
          expect(voice_media_track_count(local_video_selector)).to eq(1)
        end

        using_session(:alice) do
          remote_video_selector =
            ".voice-video-tile.--video[data-user-id='#{other_user.id}'] video.voice-video-tile__video"
          expect(page).to have_css(remote_video_selector, wait: 10)
          expect(voice_media_track_count(remote_video_selector, timeout: 10)).to eq(1)
        end
      end

      it "keeps remote video attached in widget mode" do
        SiteSetting.voice_video_enabled = true
        other_user.activate
        other_user.update!(trust_level: TrustLevel[2])
        Group.refresh_automatic_groups!

        using_session(:alice) do
          sign_in(user)
          install_voice_fake_media
          visit("/voice/r/#{room.slug}")
          click_button(I18n.t("js.voice.room.join"))
          click_room_page_widget_mode_button

          expect(page).to have_css(".voice-call-widget", text: room.name)
          expect(page).to have_current_path("/latest")
        end

        using_session(:bob) do
          sign_in(other_user)
          install_voice_fake_media(
            video_feeds: [
              {
                label: "Bob widget camera",
                width: 640,
                height: 360,
                color: "#16a34a",
                accent: "#7c3aed",
              },
            ],
          )
          visit("/voice/r/#{room.slug}")
          click_button(I18n.t("js.voice.room.join"))
          click_button(I18n.t("js.voice.video.camera_on"))

          local_video_selector =
            ".voice-video-tile.--video[data-user-id='#{other_user.id}'] video.voice-video-tile__video"
          expect(page).to have_css(local_video_selector)
          expect(voice_media_track_count(local_video_selector)).to eq(1)
        end

        using_session(:alice) do
          remote_tile_selector =
            ".voice-call-widget .voice-video-tile[data-user-id='#{other_user.id}']"
          remote_video_selector = "#{remote_tile_selector}.--video video.voice-video-tile__video"

          expect(page).to have_css(remote_tile_selector, wait: 10)
          expect(page).to have_css(remote_video_selector, wait: 10)
          expect(voice_media_track_count(remote_video_selector, timeout: 10)).to eq(1)
          expect(voice_media_track_live?(remote_video_selector, timeout: 10)).to eq(true)
        end
      end
    end

    context "with a stage room" do
      fab!(:stage_room) do
        Fabricate(
          :voice_room,
          name: "Stage Room",
          creator: user,
          public: true,
          room_type: Voice::Room::ROOM_TYPE_STAGE,
        )
      end

      before do
        other_user.activate
        SiteSetting.voice_video_enabled = true
      end

      it "lets a joined moderator publish camera video while a listener gets no capture buttons" do
        using_session(:moderator) do
          sign_in(user)
          install_voice_fake_media

          visit("/voice/r/#{stage_room.slug}")
          click_button(I18n.t("js.voice.room.join"))

          # Stage rooms feature the presenter by default instead of the grid.
          expect(page).to have_css(".voice-room-page.--presentation")

          expect(page).to have_button(I18n.t("js.voice.video.camera_on"))
          click_button(I18n.t("js.voice.video.camera_on"))

          video_selector =
            ".voice-video-tile.--video[data-user-id='#{user.id}'] video.voice-video-tile__video"
          expect(page).to have_css(video_selector)
          expect(voice_media_track_count(video_selector)).to eq(1)
        end

        using_session(:listener) do
          sign_in(other_user)
          install_voice_fake_media

          visit("/voice/r/#{stage_room.slug}")
          click_button(I18n.t("js.voice.room.join"))
          expect(page).to have_css(".voice-room-page__leave")

          expect(page).to have_css(".voice-room-page.--presentation")
          expect(page).to have_no_button(I18n.t("js.voice.video.camera_on"))
          expect(page).to have_no_button(I18n.t("js.voice.video.screen_share_start"))
        end
      end
    end

    context "as admin" do
      before do
        admin.activate
        sign_in(admin)
      end

      it "shows voice rooms section when rooms exist" do
        Fabricate(:voice_room, name: "Admin Room", creator: admin, public: true)

        visit("/latest")

        expect(voice_sidebar).to be_visible
      end
    end

    context "when user is not in create room groups" do
      fab!(:low_trust_user) { Fabricate(:user, trust_level: TrustLevel[0]) }

      before do
        low_trust_user.activate
        SiteSetting.voice_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
        sign_in(low_trust_user)
      end

      it "shows public rooms but hides private rooms" do
        public_room = Fabricate(:voice_room, name: "Public Room", creator: admin, public: true)
        private_room = Fabricate(:voice_room, name: "Private Room", creator: admin, public: false)

        visit("/latest")

        expect(voice_sidebar).to be_visible
        expect(voice_sidebar).to have_room(public_room.name)
        expect(voice_sidebar).to have_no_room(private_room.name)
      end
    end
  end
end
