# frozen_string_literal: true

require_relative "../support/voice_fake_media"

# Exercises a real LiveKit server end-to-end, so it only runs when one is
# reachable. Start a disposable dev server and point the spec at it:
#
#   docker run --rm -p 7880:7880 livekit/livekit-server --dev
#
#   VOICE_LIVEKIT_TEST_URL=ws://localhost:7880 \
#     bin/rspec plugins/voice/spec/system/voice_livekit_spec.rb
#
# The --dev server uses the API key "devkey" with secret "secret"; set
# VOICE_LIVEKIT_TEST_KEY / VOICE_LIVEKIT_TEST_SECRET to target a server
# with real credentials. Without VOICE_LIVEKIT_TEST_URL the whole file is
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
describe "Voice LiveKit rooms", if: ENV["VOICE_LIVEKIT_TEST_URL"] do
  fab!(:admin)
  fab!(:alice) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:bob) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) { Fabricate(:voice_room, name: "LiveKit Room", creator: admin, public: true) }

  before do
    alice.activate
    bob.activate
    Group.refresh_automatic_groups!

    SiteSetting.voice_enabled = true
    SiteSetting.voice_mesh_privacy_warning_enabled = false
    SiteSetting.voice_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"

    # The policy validator requires url + key + secret to be present first.
    SiteSetting.voice_livekit_url = ENV["VOICE_LIVEKIT_TEST_URL"]
    SiteSetting.voice_livekit_api_key = ENV.fetch("VOICE_LIVEKIT_TEST_KEY", "devkey")
    SiteSetting.voice_livekit_api_secret = ENV.fetch("VOICE_LIVEKIT_TEST_SECRET", "secret")
    SiteSetting.voice_livekit_room_policy = "all_rooms"
  end

  # Records WebSocket URLs so the spec can prove the browser really connected
  # to the SFU. Belt and braces on top of the transport-pin assertion below:
  # a stale client bundle once ran this whole flow green on mesh.
  def install_sfu_connection_probe
    page.driver.with_playwright_page { |pw| pw.add_init_script(script: <<~JS) }
        window.__voiceWsUrls = [];
        const NativeWebSocket = window.WebSocket;
        window.WebSocket = new Proxy(NativeWebSocket, {
          construct(target, args) {
            window.__voiceWsUrls.push(String(args[0]));
            return new target(...args);
          },
        });
      JS
  end

  def sfu_websocket_urls
    page
      .evaluate_script("window.__voiceWsUrls")
      .select { |url| url.start_with?(ENV["VOICE_LIVEKIT_TEST_URL"]) }
  end

  it "runs a two-browser camera call through the LiveKit server" do
    using_session(:alice) do
      sign_in(alice)
      install_sfu_connection_probe
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

    # The first join must have resolved and pinned the SFU transport — this
    # is what distinguishes the call below from silently running on mesh.
    expect(Voice::ParticipantTracker.pinned_transport(room.id)).to eq("livekit")

    using_session(:bob) do
      sign_in(bob)
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
        ".voice-video-tile.--video[data-user-id='#{bob.id}'] video.voice-video-tile__video"
      expect(page).to have_css(local_video_selector)
      expect(voice_media_track_count(local_video_selector)).to eq(1)
    end

    using_session(:alice) do
      # Bob's camera arrives through the SFU rather than a direct peer
      # connection; a longer wait absorbs the extra publish/subscribe hop.
      remote_video_selector =
        ".voice-video-tile.--video[data-user-id='#{bob.id}'] video.voice-video-tile__video"
      expect(page).to have_css(remote_video_selector, wait: 15)
      expect(voice_media_track_count(remote_video_selector, timeout: 15)).to eq(1)
      expect(voice_media_track_live?(remote_video_selector, timeout: 15)).to eq(true)

      expect(sfu_websocket_urls).not_to be_empty
    end
  end
end
