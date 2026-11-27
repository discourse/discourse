# frozen_string_literal: true

require_relative "../support/live_fake_media"

# Uses two independent Chromium sessions and native RTCPeerConnection.
# Only microphone/camera capture is faked; CI=1 avoids core's fixed local
# remote-debugging-port so both browsers can run concurrently.
describe "Live rooms without a microphone", allow_network: ["*.local"] do
  fab!(:first_user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:second_user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) { Fabricate(:live_room, name: "Open Meeting", creator: first_user, public: true) }

  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    first_user.activate
    second_user.activate
    Group.refresh_automatic_groups!
    SiteSetting.live_enabled = true
    SiteSetting.live_mesh_privacy_warning_enabled = false
    SiteSetting.live_stun_servers = ""
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
  end

  def install_controllable_mic_failure(error_name:, error_message:)
    install_live_fake_media

    page.driver.with_playwright_page do |playwright_page|
      playwright_page.add_init_script(script: <<~JS)
        (() => {
          window.__allowLiveMic = false;
          const originalGetUserMedia = navigator.mediaDevices.getUserMedia.bind(
            navigator.mediaDevices
          );
          navigator.mediaDevices.getUserMedia = async (constraints = {}) => {
            if (constraints.audio && !window.__allowLiveMic) {
              throw new DOMException(#{error_message.to_json}, #{error_name.to_json});
            }
            return originalGetUserMedia(constraints);
          };
        })();
      JS
    end
  end

  def join_room_page
    visit("/live/r/#{room.slug}")
    click_button(I18n.t("js.live.room.join"))
    expect(page).to have_css(".live-room-page__leave")
  end

  def has_live_remote_audio?(timeout: 15)
    page.evaluate_async_script(<<~JS, timeout * 1000)
      const [timeoutMs, done] = arguments;
      const startedAt = performance.now();
      const check = () => {
        const audios = Array.from(document.querySelectorAll(".live-voice-canvas audio"));
        const live = audios.some((audio) => {
          if (audio.muted) {
            return false;
          }
          const stream = audio.srcObject;
          if (!stream?.active) {
            return false;
          }
          return stream.getAudioTracks().some((t) => t.readyState === "live" && t.enabled);
        });
        if (live) {
          done(true);
        } else if (performance.now() - startedAt > timeoutMs) {
          done(false);
        } else {
          setTimeout(check, 100);
        }
      };
      check();
    JS
  end

  it "lets a user join muted when mic permission is denied (offerer), hear peers, see video, and unmute once granted" do
    # first_user has the lower ID, so it initiates the WebRTC offer without a mic.
    using_session(:listener) do
      sign_in(first_user)
      install_controllable_mic_failure(
        error_name: "NotAllowedError",
        error_message: "Permission denied",
      )
      join_room_page

      expect(page).to have_no_css(".live-mic-permission-modal")
      expect(toasts).to have_default(I18n.t("js.live.room.joined_without_mic_permission"))
      expect(page).to have_css(
        ".live-call-controls__mic-combo .live-call-controls__combo-main.--off",
      )
      expect(page).to have_css(
        ".live-video-tile[data-user-id='#{first_user.id}'] .d-icon-microphone-slash",
      )
    end

    using_session(:speaker) do
      sign_in(second_user)
      install_live_fake_media
      join_room_page

      expect(page).to have_css(
        ".live-video-tile[data-user-id='#{first_user.id}'] .d-icon-microphone-slash",
        wait: 10,
      )

      click_button(I18n.t("js.live.video.camera_on"))
      expect(page).to have_css(
        ".live-video-tile.--video[data-user-id='#{second_user.id}'] video.live-video-tile__video",
      )
    end

    using_session(:listener) do
      expect(has_live_remote_audio?).to eq(true)

      remote_video =
        ".live-video-tile.--video[data-user-id='#{second_user.id}'] video.live-video-tile__video"
      expect(page).to have_css(remote_video, wait: 10)
      expect(live_media_track_live?(remote_video, kind: :video, timeout: 10)).to eq(true)

      # Clicking unmute while still blocked opens the help modal without
      # dropping the room or killing incoming audio.
      find(".live-call-controls__mic-combo .live-call-controls__combo-main").click
      expect(page).to have_css(".live-mic-permission-modal")
      expect(page).to have_css(".live-room-page__leave")
      expect(has_live_remote_audio?(timeout: 3)).to eq(true)

      find(".live-mic-permission-modal__ok").click
      expect(page).to have_no_css(".live-mic-permission-modal")

      # Once mic permission is allowed, clicking unmute acquires and publishes it.
      page.execute_script("window.__allowLiveMic = true;")
      find(".live-call-controls__mic-combo .live-call-controls__combo-main").click

      expect(page).to have_css(
        ".live-call-controls__mic-combo .live-call-controls__combo-main:not(.--off)",
        wait: 10,
      )
      expect(page).to have_no_css(
        ".live-video-tile[data-user-id='#{first_user.id}'] .d-icon-microphone-slash",
      )
      expect(live_media_track_live?(remote_video, kind: :video, timeout: 10)).to eq(true)
    end

    using_session(:speaker) do
      expect(page).to have_no_css(
        ".live-video-tile[data-user-id='#{first_user.id}'] .d-icon-microphone-slash",
        wait: 10,
      )
      expect(has_live_remote_audio?).to eq(true)
    end
  end

  it "lets a user join muted with no microphone hardware (answerer), receive audio, and unmute once connected" do
    # first_user (lower ID) has a mic; second_user (higher ID) joins without one.
    using_session(:speaker) do
      sign_in(first_user)
      install_live_fake_media
      join_room_page
    end

    using_session(:listener) do
      sign_in(second_user)
      install_controllable_mic_failure(
        error_name: "NotFoundError",
        error_message: "Requested device not found",
      )
      join_room_page

      expect(page).to have_no_css(".live-mic-permission-modal")
      expect(toasts).to have_default(I18n.t("js.live.room.joined_without_mic"))
      expect(page).to have_css(
        ".live-call-controls__mic-combo .live-call-controls__combo-main.--off",
      )
      expect(has_live_remote_audio?).to eq(true)

      # Clicking unmute while still missing hardware shows the unavailable toast
      # (not the permission modal) and leaves incoming audio untouched.
      find(".live-call-controls__mic-combo .live-call-controls__combo-main").click
      expect(page).to have_no_css(".live-mic-permission-modal")
      expect(toasts).to have_error(I18n.t("js.live.room.mic_unavailable"))
      expect(has_live_remote_audio?(timeout: 3)).to eq(true)

      # Connecting a mic and clicking unmute renegotiates cleanly even as the higher-ID peer.
      page.execute_script("window.__allowLiveMic = true;")
      find(".live-call-controls__mic-combo .live-call-controls__combo-main").click

      expect(page).to have_css(
        ".live-call-controls__mic-combo .live-call-controls__combo-main:not(.--off)",
        wait: 10,
      )
    end

    using_session(:speaker) { expect(has_live_remote_audio?).to eq(true) }
  end

  it "still populates output devices in voice settings when no microphone is available" do
    sign_in(first_user)
    install_controllable_mic_failure(
      error_name: "NotFoundError",
      error_message: "Requested device not found",
    )
    join_room_page

    find("button[data-identifier='live-audio-menu']").click
    within(".fk-d-menu[data-identifier='live-audio-menu']") do
      click_button(I18n.t("js.live.voice_settings.audio_settings"))
    end

    expect(page).to have_css(".live-voice-settings-modal")
    expect(page).to have_content(I18n.t("js.live.voice_settings.mic_error"))
    output_select = PageObjects::Components::SelectKit.new(".live-voice-settings__output-select")
    expect(output_select).to have_selected_name(I18n.t("js.live.devices.system_default"))
  end
end
