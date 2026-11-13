# frozen_string_literal: true

require "tmpdir"

require_relative "../support/live_fake_media"

# Uses two independent Chromium sessions and native RTCPeerConnection/DataChannel.
# Only microphone/camera acquisition is faked. CI=1 avoids core's fixed local
# remote-debugging-port, which otherwise prevents launching the second browser.
# Core blocks DNS by default; allow only local mDNS ICE host candidates so the
# two browser processes can connect without relying on external STUN/TURN.
describe "Live mesh file transfers", allow_network: ["*.local"] do
  fab!(:alice) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:bob) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) { Fabricate(:live_room, name: "File transfer room", creator: alice, public: true) }

  let(:menu) { ".fk-d-menu[data-identifier='live-participant-menu']" }
  let(:send_button) { ".live-participant-sidebar-context-menu__send-file-btn" }

  before do
    alice.activate
    bob.activate
    Group.refresh_automatic_groups!
    SiteSetting.live_enabled = true
    SiteSetting.live_mesh_privacy_warning_enabled = false
    SiteSetting.live_stun_servers = ""
    SiteSetting.live_file_transfer_enabled = true
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
  end

  def join_room(user)
    sign_in(user)
    install_live_fake_media
    # Observe native channel traffic without replacing the transport or messages.
    page.driver.with_playwright_page { |browser| browser.add_init_script(script: <<~JS) }
        window.__filePeers = [];
        window.__fileChannels = [];
        window.__fileChannelEvidence = { opened: 0, binarySent: 0, binaryReceived: 0 };
        const observed = new WeakSet();
        function observe(channel) {
          if (observed.has(channel)) { return; }
          observed.add(channel);
          window.__fileChannels.push(channel);
          channel.addEventListener("open", () => window.__fileChannelEvidence.opened++);
          channel.addEventListener("message", ({ data }) => {
            if (typeof data !== "string") {
              window.__fileChannelEvidence.binaryReceived += data.byteLength ?? data.size;
            }
          });
          const send = channel.send.bind(channel);
          channel.send = (data) => {
            if (typeof data !== "string") {
              window.__fileChannelEvidence.binarySent += data.byteLength ?? data.size;
            }
            return send(data);
          };
        }
        const PeerConnection = window.RTCPeerConnection;
        window.RTCPeerConnection = new Proxy(PeerConnection, {
          construct(target, args) {
            const peer = new target(...args);
            window.__filePeers.push(peer);
            peer.addEventListener("datachannel", ({ channel }) => observe(channel));
            const create = peer.createDataChannel.bind(peer);
            peer.createDataChannel = (...options) => {
              const channel = create(...options);
              observe(channel);
              return channel;
            };
            return peer;
          }
        });
      JS
    visit("/live/r/#{room.slug}")
    click_button(I18n.t("js.live.room.join"))
    expect(page).to have_css(".live-room-page__leave")
  end

  def join_both
    using_session(:alice) { join_room(alice) }
    using_session(:bob) { join_room(bob) }
    using_session(:alice) do
      wait_for_browser("Discourse.lookup('service:live-webrtc').canSendFile(#{room.id}, #{bob.id})")
    end
  rescue RSpec::Expectations::ExpectationNotMetError
    %i[alice bob].each do |session|
      using_session(session) do
        warn "#{session} browser diagnostics: #{page.evaluate_script(<<~JS).to_json}"
          (() => {
            const service = Discourse.lookup("service:live-webrtc");
            return {
              setting: Discourse.lookup("service:site-settings").live_file_transfer_enabled,
              room: service.activeRoom,
              state: service.connectionStateFor(#{room.id}),
              evidence: window.__fileChannelEvidence,
              peers: window.__filePeers.map(p => ({
                connection: p.connectionState, ice: p.iceConnectionState,
                signaling: p.signalingState, sctp: p.sctp?.state,
                local: p.localDescription?.sdp?.split(String.fromCharCode(10)).filter(l => l.startsWith("a=candidate")),
                remote: p.remoteDescription?.sdp?.split(String.fromCharCode(10)).filter(l => l.startsWith("a=candidate")),
              })),
              channels: window.__fileChannels.map(c => ({ label: c.label, state: c.readyState, id: c.id })),
            };
          })()
        JS
      end
    end
    raise
  end

  def wait_for_browser(expression)
    try_until_success(timeout: 15) { expect(page.evaluate_script(expression)).to eq(true) }
  end

  def transfers
    "Discourse.lookup('service:live-webrtc').fileTransfers"
  end

  def expect_status(id, status)
    wait_for_browser(
      "#{transfers}.some(t => t.id === #{id.to_json} && t.status === #{status.to_json})",
    )
  end

  def send_file(name, bytes)
    find(".live-video-tile[data-user-id='#{bob.id}']").right_click
    within(menu) { find(send_button).click }
    expect(page).to have_css(".live-send-file-modal")
    Dir.mktmpdir("live-file-transfer") do |directory|
      path = File.join(directory, name)
      File.binwrite(path, bytes.pack("C*"))
      find(".live-send-file-modal input[type='file']").attach_file(path)
      expect(page).to have_no_css(".live-send-file-modal")
    end
    wait_for_browser("#{transfers}.some(t => t.name === #{name.to_json})")
    page.evaluate_script("#{transfers}.find(t => t.name === #{name.to_json}).id")
  end

  def transfer_action(action, id)
    css = {
      "acceptFileTransfer" => "accept",
      "rejectFileTransfer" => "reject",
      "cancelFileTransfer" => "cancel",
      "dismissFileTransfer" => "dismiss",
    }.fetch(action)
    find("[data-transfer-id='#{id}'] .live-file-transfer__#{css}").click
  end

  def expect_received_bytes(id, bytes)
    received = page.evaluate_async_script(<<~JS, id)
      const [id, done] = arguments;
      Discourse.lookup("service:live-webrtc").fileTransfers.find(t => t.id === id)
        .blob.arrayBuffer().then(buffer => done(JSON.stringify(Array.from(new Uint8Array(buffer)))));
    JS
    expect(JSON.parse(received)).to eq(bytes)
  end

  it "offers the shared participant action in the sidebar and video tile, but hides it when disabled" do
    join_both
    using_session(:alice) do
      row = "[data-link-name='live-participant-#{room.id}-#{bob.id}']"
      find(row).right_click
      within(menu) { expect(page).to have_css(send_button) }
      page.send_keys(:escape)
      find(row).hover
      find("#{row} .sidebar-section-hover-button").click
      within(menu) { expect(page).to have_css(send_button) }
      page.send_keys(:escape)

      find(".live-video-tile[data-user-id='#{bob.id}']").right_click
      within(menu) { expect(page).to have_css(send_button) }
      page.send_keys(:escape)
    end

    SiteSetting.live_file_transfer_enabled = false
    using_session(:alice) do
      page.refresh
      click_button(I18n.t("js.live.room.join"))
      expect(page).to have_css(".live-room-page__leave")
      find(".live-video-tile[data-user-id='#{bob.id}']").right_click
      within(menu) { expect(page).to have_no_css(send_button) }
      page.send_keys(:escape)
      row = "[data-link-name='live-participant-#{room.id}-#{bob.id}']"
      find(row).right_click
      within(menu) { expect(page).to have_no_css(send_button) }
      expect(
        page.evaluate_script(
          "Discourse.lookup('service:live-webrtc').canSendFile(#{room.id}, #{bob.id})",
        ),
      ).to eq(false)
    end
  end

  it "requires acceptance before binary bytes and completes binary and empty files with matching bytes" do
    join_both
    bytes = [0, 255, 128, 13, 10, 0, 42] * 5000
    binary_wire_bytes = 0
    [["binary.dat", bytes], ["empty.dat", []]].each do |name, contents|
      id = using_session(:alice) { send_file(name, contents) }
      using_session(:alice) { expect_status(id, "waiting") }
      using_session(:bob) do
        expect_status(id, "pending")
        expect(page.evaluate_script("window.__fileChannelEvidence.binaryReceived")).to eq(
          binary_wire_bytes,
        )
        expect(
          page.evaluate_script("#{transfers}.find(t => t.id === #{id.to_json}).blob == null"),
        ).to eq(true)
      end
      using_session(:alice) do
        expect(page.evaluate_script("window.__fileChannelEvidence.binarySent")).to eq(
          binary_wire_bytes,
        )
      end
      using_session(:bob) { transfer_action("acceptFileTransfer", id) }
      using_session(:alice) { expect_status(id, "completed") }
      using_session(:bob) do
        expect_status(id, "completed")
        expect_received_bytes(id, contents)
        page.driver.with_playwright_page do |browser|
          download =
            browser.expect_download do
              find("[data-transfer-id='#{id}'] .live-file-transfer__save").click
            end
          expect(download.suggested_filename).to eq(name)
          expect(File.binread(download.path).bytes).to eq(contents)
        end
        expect(page.evaluate_script("window.__fileChannelEvidence.opened")).to be > 0
        received_wire_bytes = page.evaluate_script("window.__fileChannelEvidence.binaryReceived")
        if contents.empty?
          expect(received_wire_bytes).to eq(binary_wire_bytes)
        else
          expect(received_wire_bytes).to be >= bytes.length
        end
        binary_wire_bytes = received_wire_bytes
        transfer_action("dismissFileTransfer", id)
        wait_for_browser("!#{transfers}.some(t => t.id === #{id.to_json})")
      end
    end
  end

  it "propagates rejection and sender cancellation without sending binary data" do
    join_both
    rejected = using_session(:alice) { send_file("reject.dat", [0, 255]) }
    using_session(:bob) do
      expect_status(rejected, "pending")
      transfer_action("rejectFileTransfer", rejected)
      expect_status(rejected, "rejected")
    end
    using_session(:alice) { expect_status(rejected, "rejected") }

    cancelled = using_session(:alice) { send_file("cancel.dat", [0, 255]) }
    using_session(:bob) { expect_status(cancelled, "pending") }
    using_session(:alice) do
      transfer_action("cancelFileTransfer", cancelled)
      expect_status(cancelled, "cancelled")
      expect(page.evaluate_script("window.__fileChannelEvidence.binarySent")).to eq(0)
    end
    using_session(:bob) do
      expect_status(cancelled, "cancelled")
      expect(page.evaluate_script("window.__fileChannelEvidence.binaryReceived")).to eq(0)
    end
  end

  it "cleans up a pending transfer when the peer leaves" do
    join_both
    id = using_session(:alice) { send_file("disconnect.dat", [1, 2, 3]) }
    using_session(:bob) do
      expect_status(id, "pending")
      toggle = find(".live-file-transfers__toggle")
      expect(toggle["aria-expanded"]).to eq("true")
      expect(toggle["aria-controls"]).to eq("live-file-transfers-list")
      toggle.click
      expect(toggle["aria-expanded"]).to eq("false")
      expect(page).to have_no_css("#live-file-transfers-list [data-transfer-id='#{id}']")
      toggle.click
      expect(toggle["aria-expanded"]).to eq("true")
      expect(page).to have_css("#live-file-transfers-list [data-transfer-id='#{id}']")
      click_button(I18n.t("js.live.room.leave"))
      wait_for_browser(
        "!#{transfers}.some(t => ['pending', 'waiting', 'transferring'].includes(t.status))",
      )
    end
    using_session(:alice) do
      wait_for_browser(
        "!Discourse.lookup('service:live-webrtc').canSendFile(#{room.id}, #{bob.id})",
      )
      wait_for_browser(
        "!#{transfers}.some(t => t.id === #{id.to_json} && ['pending', 'waiting', 'transferring'].includes(t.status))",
      )
      expect(page.evaluate_script("window.__fileChannelEvidence.binarySent")).to eq(0)
    end
  end
end
