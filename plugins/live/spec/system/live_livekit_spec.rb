# frozen_string_literal: true

require_relative "../support/live_fake_media"

# Exercises a real LiveKit server end-to-end, so it only runs when one is
# reachable. Start a disposable dev server and point the spec at it:
#
#   docker run --rm -p 7880:7880 livekit/livekit-server --dev
#
#   LIVE_LIVEKIT_TEST_URL=ws://localhost:7880 \
#     bin/rspec plugins/live/spec/system/live_livekit_spec.rb
#
# The --dev server uses the API key "devkey" with secret "secret"; set
# LIVE_LIVEKIT_TEST_KEY / LIVE_LIVEKIT_TEST_SECRET to target a server
# with real credentials. Without LIVE_LIVEKIT_TEST_URL the whole file is
# excluded, keeping CI runs byte-identical to before it existed.
#
# NOTE: outside CI, core pins every test browser to one fixed
# --remote-debugging-port, so any spec that opens a second session (this one,
# and the mesh two-browser specs) needs CI=1 in the environment to launch the
# second browser locally.
#
# Besides the transport itself, this doubles as the proof that the fake
# media harness satisfies the LiveKit SDK: livekit-client never calls
# getUserMedia here — the service acquires media itself (through the fakes)
# and hands the SDK finished MediaStreamTracks via publishTrack, exactly as
# it hands them to RTCPeerConnection on the mesh path.
describe "Live LiveKit rooms", if: ENV["LIVE_LIVEKIT_TEST_URL"] do
  fab!(:admin)
  fab!(:alice) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:bob) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) { Fabricate(:live_room, name: "LiveKit Room", creator: admin, public: true) }

  before do
    alice.activate
    bob.activate
    Group.refresh_automatic_groups!

    SiteSetting.live_enabled = true
    SiteSetting.live_mesh_privacy_warning_enabled = false
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"

    # The policy validator requires url + key + secret to be present first.
    SiteSetting.live_livekit_url = ENV["LIVE_LIVEKIT_TEST_URL"]
    SiteSetting.live_livekit_api_key = ENV.fetch("LIVE_LIVEKIT_TEST_KEY", "devkey")
    SiteSetting.live_livekit_api_secret = ENV.fetch("LIVE_LIVEKIT_TEST_SECRET", "secret")
    SiteSetting.live_livekit_room_policy = "all_rooms"
  end

  # Records WebSocket URLs so the spec can prove the browser really connected
  # to the SFU. Belt and braces on top of the transport-pin assertion below:
  # a stale client bundle once ran this whole flow green on mesh.
  def install_sfu_connection_probe
    page.driver.with_playwright_page { |pw| pw.add_init_script(script: <<~JS) }
        window.__liveWsUrls = [];
        const NativeWebSocket = window.WebSocket;
        window.WebSocket = new Proxy(NativeWebSocket, {
          construct(target, args) {
            window.__liveWsUrls.push(String(args[0]));
            return new target(...args);
          },
        });
      JS
  end

  def sfu_websocket_urls
    page
      .evaluate_script("window.__liveWsUrls")
      .select { |url| url.start_with?(ENV["LIVE_LIVEKIT_TEST_URL"]) }
  end

  it "runs a two-browser camera call through the LiveKit server" do
    using_session(:alice) do
      sign_in(alice)
      install_sfu_connection_probe
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

    # The first join must have resolved and pinned the SFU transport — this
    # is what distinguishes the call below from silently running on mesh.
    expect(Live::ParticipantTracker.pinned_transport(room.id)).to eq("livekit")

    using_session(:bob) do
      sign_in(bob)
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
        ".live-video-tile.--video[data-user-id='#{bob.id}'] video.live-video-tile__video"
      expect(page).to have_css(local_video_selector)
      expect(live_media_track_count(local_video_selector)).to eq(1)
    end

    using_session(:alice) do
      # Bob's camera arrives through the SFU rather than a direct peer
      # connection; a longer wait absorbs the extra publish/subscribe hop.
      remote_video_selector =
        ".live-video-tile.--video[data-user-id='#{bob.id}'] video.live-video-tile__video"
      expect(page).to have_css(remote_video_selector, wait: 15)
      expect(live_media_track_count(remote_video_selector, timeout: 15)).to eq(1)
      expect(live_media_track_live?(remote_video_selector, timeout: 15)).to eq(true)

      expect(sfu_websocket_urls).not_to be_empty
    end
  end
end
