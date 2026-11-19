# frozen_string_literal: true

require_relative "page_objects/components/live_sidebar"
require_relative "../support/live_fake_media"

describe "Live rooms" do
  let(:live_sidebar) { PageObjects::Components::LiveSidebar.new }

  def click_room_page_widget_mode_button
    find("button[data-identifier='live-room-menu']").click
    within(".fk-d-menu[data-identifier='live-room-menu']") do
      click_button(I18n.t("js.live.room.widget_mode"))
    end
  end

  def click_call_widget_open_page_button
    within(".live-call-widget__controls") do
      find(".d-icon-discourse-expand").ancestor("button").click
    end
  end

  def click_call_widget_leave_button
    within(".live-call-widget__controls") { find(".live-call-widget__leave").click }
  end

  def switch_layout(layout_label)
    find("button[data-identifier='live-room-menu']").click
    within(".fk-d-menu[data-identifier='live-room-menu']") do
      click_button(I18n.t("js.live.room.layout"))
    end
    click_button(layout_label)
  end

  fab!(:user)
  fab!(:other_user, :user)
  fab!(:admin)

  before do
    user.activate
    SiteSetting.live_enabled = true
    SiteSetting.live_mesh_privacy_warning_enabled = false
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.live_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
  end

  context "when plugin is disabled" do
    it "does not show live rooms section" do
      SiteSetting.live_enabled = false
      Fabricate(:live_room, name: "Test Room", creator: admin, public: true)
      sign_in(user)

      visit("/latest")

      expect(live_sidebar).to be_not_visible
    end
  end

  context "when plugin is enabled" do
    context "as anonymous user" do
      it "shows public rooms when access is open to everyone" do
        Fabricate(:live_room, name: "Test Room", creator: admin, public: true)

        visit("/latest")

        expect(live_sidebar).to be_visible
      end

      it "does not show live rooms section when access is restricted to a group" do
        SiteSetting.live_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
        Fabricate(:live_room, name: "Test Room", creator: admin, public: true)

        visit("/latest")

        expect(live_sidebar).to be_not_visible
      end
    end

    context "as logged in user" do
      fab!(:room) { Fabricate(:live_room, name: "Test Room", creator: admin, public: true) }

      before do
        user.update!(trust_level: TrustLevel[2])
        Group.refresh_automatic_groups!
        sign_in(user)
      end

      it "shows live rooms section when rooms exist" do
        visit("/latest")

        expect(live_sidebar).to be_visible
      end

      it "displays public rooms in the sidebar" do
        visit("/latest")

        expect(live_sidebar).to be_visible
        expect(live_sidebar).to have_room(room.name)
      end

      it "hides private rooms from non-members even when they can create rooms" do
        private_room = Fabricate(:live_room, name: "Private Room", creator: admin, public: false)

        visit("/latest")

        expect(live_sidebar).to have_room(room.name)
        expect(live_sidebar).to have_no_room(private_room.name)
      end

      it "shows private rooms to their members" do
        private_room = Fabricate(:live_room, name: "Private Room", creator: admin, public: false)
        private_room.room_memberships.create!(user: user)

        visit("/latest")

        expect(live_sidebar).to have_room(private_room.name)
      end

      it "can publish a fake camera stream on the room page" do
        install_live_fake_media

        visit("/live/r/#{room.slug}")
        click_button(I18n.t("js.live.room.join"))

        expect(page).to have_button(I18n.t("js.live.video.camera_on"))
        click_button(I18n.t("js.live.video.camera_on"))

        video_selector =
          ".live-video-tile.--video[data-user-id='#{user.id}'] video.live-video-tile__video"
        expect(page).to have_css(video_selector)
        expect(live_media_track_count(video_selector)).to eq(1)
      end

      it "switches between presentation and tiled layouts from the menu" do
        install_live_fake_media

        visit("/live/r/#{room.slug}")
        click_button(I18n.t("js.live.room.join"))
        expect(page).to have_css(".live-room-page__leave")
        expect(page).to have_css(".live-room-page.--tiled")

        switch_layout(I18n.t("js.live.video.layout_presentation"))
        expect(page).to have_css(".live-room-page.--presentation")

        switch_layout(I18n.t("js.live.video.layout_tiled"))
        expect(page).to have_css(".live-room-page.--tiled")
      end

      it "keeps the active call in a widget after switching to widget mode" do
        install_live_fake_media

        visit("/live/r/#{room.slug}")
        click_button(I18n.t("js.live.room.join"))
        click_button(I18n.t("js.live.video.camera_on"))

        click_room_page_widget_mode_button

        expect(page).to have_css(".live-call-widget", text: room.name)
        expect(page).to have_button(I18n.t("js.live.video.camera_off"))

        widget_video_selector =
          ".live-call-widget .live-video-tile.--video[data-user-id='#{user.id}'] video.live-video-tile__video"
        expect(page).to have_css(widget_video_selector)
        expect(live_media_track_count(widget_video_selector)).to eq(1)

        click_call_widget_open_page_button

        page_video_selector =
          ".live-room-page .live-video-tile.--video[data-user-id='#{user.id}'] video.live-video-tile__video"
        expect(page).to have_current_path("/live/r/#{room.slug}")
        expect(page).to have_css(page_video_selector)
        expect(live_media_track_count(page_video_selector)).to eq(1)
      end

      it "can stop video and leave the call from the persistent widget" do
        install_live_fake_media

        visit("/live/r/#{room.slug}")
        click_button(I18n.t("js.live.room.join"))
        click_button(I18n.t("js.live.video.camera_on"))

        click_room_page_widget_mode_button

        within(".live-call-widget") { click_button(I18n.t("js.live.video.camera_off")) }

        expect(page).to have_button(I18n.t("js.live.video.camera_on"))
        expect(page).to have_no_css(".live-call-widget .live-video-tile.--video")

        click_call_widget_leave_button

        expect(page).to have_no_css(".live-call-widget")
      end

      it "opens room actions from the widget overflow menu" do
        install_live_fake_media

        visit("/live/r/#{room.slug}")
        click_button(I18n.t("js.live.room.join"))
        click_room_page_widget_mode_button

        expect(page).to have_css(".live-call-widget", text: room.name)

        # The overflow menu portals out at the dropdown z-index; opening it and
        # clicking an item asserts it renders above the widget rather than
        # behind it.
        find(".live-call-widget button[data-identifier='live-widget-room-menu']").click
        within(".fk-d-menu[data-identifier='live-widget-room-menu']") do
          click_button(I18n.t("js.live.room.info"))
        end

        expect(page).to have_css(".live-room-info-modal")
      end

      it "shows remote fake video when another user publishes a camera stream" do
        other_user.activate
        other_user.update!(trust_level: TrustLevel[2])
        Group.refresh_automatic_groups!

        using_session(:alice) do
          sign_in(user)
          install_live_fake_media(
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
          visit("/live/r/#{room.slug}")
          click_button(I18n.t("js.live.room.join"))
          expect(page).to have_button(I18n.t("js.live.video.camera_on"))
        end

        using_session(:bob) do
          sign_in(other_user)
          install_live_fake_media(
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
          visit("/live/r/#{room.slug}")
          click_button(I18n.t("js.live.room.join"))
          click_button(I18n.t("js.live.video.camera_on"))

          local_video_selector =
            ".live-video-tile.--video[data-user-id='#{other_user.id}'] video.live-video-tile__video"
          expect(page).to have_css(local_video_selector)
          expect(live_media_track_count(local_video_selector)).to eq(1)
        end

        using_session(:alice) do
          remote_video_selector =
            ".live-video-tile.--video[data-user-id='#{other_user.id}'] video.live-video-tile__video"
          expect(page).to have_css(remote_video_selector, wait: 10)
          expect(live_media_track_count(remote_video_selector, timeout: 10)).to eq(1)
        end
      end

      it "keeps remote video attached in widget mode" do
        other_user.activate
        other_user.update!(trust_level: TrustLevel[2])
        Group.refresh_automatic_groups!

        using_session(:alice) do
          sign_in(user)
          install_live_fake_media
          visit("/live/r/#{room.slug}")
          click_button(I18n.t("js.live.room.join"))
          click_room_page_widget_mode_button

          expect(page).to have_css(".live-call-widget", text: room.name)
          expect(page).to have_current_path("/latest")
        end

        using_session(:bob) do
          sign_in(other_user)
          install_live_fake_media(
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
          visit("/live/r/#{room.slug}")
          click_button(I18n.t("js.live.room.join"))
          click_button(I18n.t("js.live.video.camera_on"))

          local_video_selector =
            ".live-video-tile.--video[data-user-id='#{other_user.id}'] video.live-video-tile__video"
          expect(page).to have_css(local_video_selector)
          expect(live_media_track_count(local_video_selector)).to eq(1)
        end

        using_session(:alice) do
          remote_tile_selector =
            ".live-call-widget .live-video-tile[data-user-id='#{other_user.id}']"
          remote_video_selector = "#{remote_tile_selector}.--video video.live-video-tile__video"

          expect(page).to have_css(remote_tile_selector, wait: 10)
          expect(page).to have_css(remote_video_selector, wait: 10)
          expect(live_media_track_count(remote_video_selector, timeout: 10)).to eq(1)
          expect(live_media_track_live?(remote_video_selector, timeout: 10)).to eq(true)
        end
      end

      it "lets the creator delete their own room" do
        owned_room = Fabricate(:live_room, name: "My Room", creator: user, public: true)

        visit("/latest")
        live_sidebar.room_link(owned_room.id).hover
        live_sidebar.room_link(owned_room.id).find(".sidebar-section-hover-button").click
        click_button(I18n.t("js.live.room.edit"))
        click_button(I18n.t("js.live.room.delete"))
        find(".dialog-footer .btn-danger").click

        expect(live_sidebar).to have_no_room_link(owned_room.id)
        expect(Live::Room.exists?(owned_room.id)).to eq(false)
      end

      it "does not offer deletion of rooms the user does not own" do
        room.room_memberships.create!(user: user, role: Live::RoomMembership::ROLE_MODERATOR)

        visit("/latest")
        live_sidebar.room_link(room.id).hover
        live_sidebar.room_link(room.id).find(".sidebar-section-hover-button").click
        click_button(I18n.t("js.live.room.edit"))

        expect(page).to have_css(".live-room-info-modal__edit-form")
        expect(page).to have_no_css(".live-room-info-modal__delete-btn")
      end
    end

    context "with a stage room" do
      fab!(:stage_room) do
        Fabricate(
          :live_room,
          name: "Stage Room",
          creator: user,
          public: true,
          room_type: Live::Room::ROOM_TYPE_STAGE,
        )
      end

      before { other_user.activate }

      it "lets a joined moderator publish camera video while a listener gets no capture buttons" do
        using_session(:moderator) do
          sign_in(user)
          install_live_fake_media

          visit("/live/r/#{stage_room.slug}")
          click_button(I18n.t("js.live.room.join"))

          # Stage rooms feature the presenter by default instead of the grid.
          expect(page).to have_css(".live-room-page.--presentation")

          expect(page).to have_button(I18n.t("js.live.video.camera_on"))
          click_button(I18n.t("js.live.video.camera_on"))

          video_selector =
            ".live-video-tile.--video[data-user-id='#{user.id}'] video.live-video-tile__video"
          expect(page).to have_css(video_selector)
          expect(live_media_track_count(video_selector)).to eq(1)
        end

        using_session(:listener) do
          sign_in(other_user)
          install_live_fake_media

          visit("/live/r/#{stage_room.slug}")
          click_button(I18n.t("js.live.room.join"))
          expect(page).to have_css(".live-room-page__leave")

          expect(page).to have_css(".live-room-page.--presentation")
          expect(page).to have_no_button(I18n.t("js.live.video.camera_on"))
          expect(page).to have_no_button(I18n.t("js.live.video.screen_share_start"))
        end
      end
    end

    context "as admin" do
      before do
        admin.activate
        sign_in(admin)
      end

      it "shows live rooms section when rooms exist" do
        Fabricate(:live_room, name: "Admin Room", creator: admin, public: true)

        visit("/latest")

        expect(live_sidebar).to be_visible
      end
    end

    context "when user is not in create room groups" do
      fab!(:low_trust_user) { Fabricate(:user, trust_level: TrustLevel[0]) }

      before do
        low_trust_user.activate
        SiteSetting.live_create_room_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_2]}"
        sign_in(low_trust_user)
      end

      it "shows public rooms but hides private rooms" do
        public_room = Fabricate(:live_room, name: "Public Room", creator: admin, public: true)
        private_room = Fabricate(:live_room, name: "Private Room", creator: admin, public: false)

        visit("/latest")

        expect(live_sidebar).to be_visible
        expect(live_sidebar).to have_room(public_room.name)
        expect(live_sidebar).to have_no_room(private_room.name)
      end
    end
  end
end
