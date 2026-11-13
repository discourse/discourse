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
  fab!(:sender_group, :group)
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
    sender_group.add(alice)
    SiteSetting.live_file_transfer_allowed_groups = sender_group.id.to_s
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
        window.__fileChannelEvidence = { opened: 0, binarySent: 0, binaryReceived: 0, offersReceived: 0 };
        // Transparent observation, not replacement storage: native getFile()
        // must supply the completed File, with no JS Blob/File assembly or
        // eager whole-file read before the user explicitly reads or saves it.
        window.__fileMemoryCopies = [];
        for (const name of ["Blob", "File"]) {
          const Constructor = window[name];
          window[name] = new Proxy(Constructor, {
            construct(target, args, newTarget) {
              const result = Reflect.construct(target, args, newTarget);
              if (window.__fileWatchMemory && result.size === window.__fileWatchSize) {
                window.__fileMemoryCopies.push(`new ${name}`);
              }
              return result;
            }
          });
        }
        for (const method of ["arrayBuffer", "text"]) {
          const original = Blob.prototype[method];
          Blob.prototype[method] = function(...args) {
            if (window.__fileWatchMemory && this.size === window.__fileWatchSize) {
              window.__fileMemoryCopies.push(method);
            }
            return original.apply(this, args);
          };
        }
        const observed = new WeakSet();
        function observe(channel) {
          if (observed.has(channel)) { return; }
          observed.add(channel);
          window.__fileChannels.push(channel);
          channel.addEventListener("open", () => window.__fileChannelEvidence.opened++);
          channel.addEventListener("message", ({ data }) => {
            if (typeof data === "string") {
              try {
                if (JSON.parse(data).type === "offer") {
                  window.__fileChannelEvidence.offersReceived++;
                }
              } catch {}
            } else {
              window.__fileChannelEvidence.binaryReceived += data.byteLength ?? data.size;
              // Automate the real UI after native traffic begins, before a local
              // transfer can finish between Capybara polling intervals.
              const abort = window.__fileAbortOnBinary;
              if (abort) {
                window.__fileAbortOnBinary = null;
                setTimeout(async () => {
                  // Capture actual native handles before the action deletes them.
                  window.__fileBackingAtAbort = [];
                  try {
                    const root = await navigator.storage.getDirectory();
                    const directory = await root.getDirectoryHandle("live-file-transfers");
                    async function walk(parent, prefix = "") {
                      for await (const [name, handle] of parent.entries()) {
                        const path = `${prefix}${name}`;
                        if (handle.kind === "directory") {
                          await walk(handle, `${path}/`);
                        } else {
                          window.__fileBackingAtAbort.push(path);
                        }
                      }
                    }
                    await walk(directory);
                  } catch (error) {
                    window.__fileBackingError = `${error.name}: ${error.message}`;
                  }
                  const selector = abort === "leave"
                    ? ".live-room-page__leave"
                    : `[data-transfer-id='${abort}'] .live-file-transfer__cancel`;
                  document.querySelector(selector)?.click();
                }, 0);
              }
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

  def join_both(sender_allowed: true)
    using_session(:alice) { join_room(alice) }
    using_session(:bob) { join_room(bob) }
    using_session(:alice) do
      if sender_allowed
        wait_for_browser(
          "Discourse.lookup('service:live-webrtc').canSendFile(#{room.id}, #{bob.id})",
        )
      end
      expect(
        page.evaluate_script("Discourse.lookup('service:current-user').live_can_send_files"),
      ).to eq(sender_allowed)
    end
    using_session(:bob) do
      wait_for_browser(<<~JS)
        (() => {
          const participants = Discourse.lookup("service:live-rooms").roomById(#{room.id})?.active_participants;
          return participants?.some(p => p.id === #{alice.id} && p.can_send_files === #{sender_allowed}) &&
            participants.some(p => p.id === #{bob.id} && p.can_send_files === false);
        })()
      JS
      expect(
        page.evaluate_script("Discourse.lookup('service:current-user').live_can_send_files"),
      ).to eq(false)
      expect(
        page.evaluate_script(
          "Discourse.lookup('service:live-webrtc').canSendFile(#{room.id}, #{alice.id})",
        ),
      ).to eq(false)
    end
  rescue RSpec::Expectations::ExpectationNotMetError
    %i[alice bob].each do |session|
      using_session(session) do
        warn "#{session} browser diagnostics: #{page.evaluate_script(<<~JS).to_json}"
          (() => {
            const service = Discourse.lookup("service:live-webrtc");
            return {
              allowed: Discourse.lookup("service:current-user").live_can_send_files,
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
      (async () => {
        const file = await Discourse.lookup("service:live-webrtc").getReceivedFile(id);
        return {
          nativeFile: file instanceof File,
          bytes: Array.from(new Uint8Array(await file.arrayBuffer())),
        };
      })().then(result => done(JSON.stringify(result)), error => {
        done(JSON.stringify({ error: `${error.name}: ${error.message}` }));
      });
    JS
    received = JSON.parse(received)
    expect(received).not_to have_key("error")
    expect(received.fetch("nativeFile")).to eq(true)
    expect(received.fetch("bytes")).to eq(bytes)
  end

  # Inspect native storage without creating either a directory or a file.
  # Recursion tolerates session-specific directories under the shared namespace.
  def opfs_files
    result = page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      (async () => {
        const root = await navigator.storage.getDirectory();
        let directory;
        try {
          directory = await root.getDirectoryHandle("live-file-transfers");
        } catch (error) {
          if (error.name === "NotFoundError") { return []; }
          throw error;
        }
        const files = [];
        async function walk(parent, prefix = "") {
          for await (const [name, handle] of parent.entries()) {
            const path = `${prefix}${name}`;
            if (handle.kind === "directory") {
              await walk(handle, `${path}/`);
            } else {
              const file = await handle.getFile();
              files.push({ path, size: file.size });
            }
          }
        }
        await walk(directory);
        return files.sort((a, b) => a.path.localeCompare(b.path));
      })().then(files => done(JSON.stringify({ files })), error => {
        done(JSON.stringify({ error: `${error.name}: ${error.message}` }));
      });
    JS
    result = JSON.parse(result)
    expect(result).not_to have_key("error")
    result.fetch("files")
  end

  def expect_no_opfs_files(existing_paths = [])
    try_until_success(timeout: 15) do
      expect(opfs_files.reject { |file| existing_paths.include?(file.fetch("path")) }).to eq([])
    end
  end

  it "offers the shared participant action in the sidebar and video tile, but hides it for nonmembers and empty allowed groups" do
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

    using_session(:bob) do
      find(".live-video-tile[data-user-id='#{alice.id}']").right_click
      within(menu) { expect(page).to have_no_css(send_button) }
      page.send_keys(:escape)
    end

    SiteSetting.live_file_transfer_allowed_groups = ""
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
      # Prior exported files may still be retained by the download grace period.
      # Compare paths so expiry of an older export does not affect this transfer.
      existing_paths = using_session(:bob) { opfs_files.map { |file| file.fetch("path") } }
      id = using_session(:alice) { send_file(name, contents) }
      using_session(:alice) { expect_status(id, "waiting") }
      using_session(:bob) do
        expect_status(id, "pending")
        expect(opfs_files.map { |file| file.fetch("path") } - existing_paths).to eq([])
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
      using_session(:bob) do
        page.execute_script(
          "window.__fileWatchSize = #{contents.length}; window.__fileMemoryCopies = []; window.__fileWatchMemory = true;",
        )
        transfer_action("acceptFileTransfer", id)
      end
      using_session(:alice) { expect_status(id, "completed") }
      using_session(:bob) do
        expect_status(id, "completed")
        page.execute_script("window.__fileWatchMemory = false")
        expect(page.evaluate_script("window.__fileMemoryCopies")).to eq([])
        expect(
          page.evaluate_script(
            "#{transfers}.some(t => t.id === #{id.to_json} && t.hasFile === true && !Object.hasOwn(t, 'blob'))",
          ),
        ).to eq(true)
        files = opfs_files.reject { |file| existing_paths.include?(file.fetch("path")) }
        expect(files.length).to eq(1)
        expect(files.first.fetch("size")).to eq(contents.length)
        # Explicit test/user reads are intentional; eager-read observation above
        # covers only receiving and completion, before getReceivedFile or Save.
        expect_received_bytes(id, contents)
        expect(
          page.evaluate_script(
            "#{transfers}.some(t => t.id === #{id.to_json} && t.hasFile === true && !Object.hasOwn(t, 'blob'))",
          ),
        ).to eq(true)
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
        # Explicit export retains the backing file during the 30-second lazy
        # download grace period; do not wait out that timer in a browser spec.
        expect(opfs_files).to include(files.first)
      end
    end
  end

  it "propagates rejection and sender cancellation without sending binary data" do
    join_both
    existing_paths = using_session(:bob) { opfs_files.map { |file| file.fetch("path") } }
    rejected = using_session(:alice) { send_file("reject.dat", [0, 255]) }
    using_session(:bob) do
      expect_status(rejected, "pending")
      transfer_action("rejectFileTransfer", rejected)
      expect_status(rejected, "rejected")
      expect_no_opfs_files(existing_paths)
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
      expect_no_opfs_files(existing_paths)
      expect(page.evaluate_script("window.__fileChannelEvidence.binaryReceived")).to eq(0)
    end
  end

  it "cleans up a pending transfer when the peer leaves" do
    join_both
    existing_paths = using_session(:bob) { opfs_files.map { |file| file.fetch("path") } }
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
      expect_no_opfs_files(existing_paths)
      click_button(I18n.t("js.live.room.leave"))
      expect_no_opfs_files(existing_paths)
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

  it "does not accept incoming offers when no groups are allowed to send" do
    SiteSetting.live_file_transfer_allowed_groups = ""
    join_both(sender_allowed: false)
    existing_paths = using_session(:bob) { opfs_files.map { |file| file.fetch("path") } }
    using_session(:alice) do
      wait_for_browser("window.__fileChannels.some(c => c.readyState === 'open')")
      # Exercise the remote authorization boundary even if a client bypasses its
      # hidden menu. This is still an offer over the native RTC data channel.
      page.execute_script(<<~JS)
        window.__fileChannels.find(c => c.readyState === "open").send(JSON.stringify({
          type: "offer", id: crypto.randomUUID(), name: "unauthorized.dat", size: 3
        }));
      JS
    end
    using_session(:bob) do
      # Observation happens on the real ordered channel; wait for delivery, not
      # an arbitrary sleep or the absence of an offer that has not arrived yet.
      wait_for_browser("window.__fileChannelEvidence.offersReceived === 1")
      expect(page.evaluate_script("#{transfers}.length")).to eq(0)
      expect(page).to have_no_css(".live-file-transfer__accept")
      expect_no_opfs_files(existing_paths)
      expect(page.evaluate_script("window.__fileChannelEvidence.binaryReceived")).to eq(0)
    end
  end

  def abort_accepted_transfer(action)
    join_both
    existing_paths = using_session(:bob) { opfs_files.map { |file| file.fetch("path") } }
    # Large enough to remain in progress while native handles are inspected and
    # the first frame triggers the UI action. No large WebDriver JSON arguments.
    id =
      using_session(:alice) do
        send_file("#{action}-partial.dat", [0, 255, 128, 42] * (4 * 1024 * 1024))
      end
    using_session(:bob) do
      expect_status(id, "pending")
      expect(opfs_files.map { |file| file.fetch("path") } - existing_paths).to eq([])
      page.execute_script(
        "window.__fileAbortOnBinary = #{(action == "leave" ? "leave" : id).to_json}",
      )
      transfer_action("acceptFileTransfer", id)
      wait_for_browser("window.__fileChannelEvidence.binaryReceived > 0")
      if action == "cancel"
        expect_status(id, "cancelled")
      else
        expect(page).to have_no_css(".live-room-page__leave")
        wait_for_browser("!#{transfers}.some(t => t.id === #{id.to_json})")
      end
      expect(page.evaluate_script("window.__fileBackingError")).to be_nil
      # Chromium can expose an additional swap file while createWritable is
      # open. Capture every new path, then require cleanup of the entire unique
      # namespace, including swap files, without counting unrelated exports.
      allocated_paths = page.evaluate_script("window.__fileBackingAtAbort") - existing_paths
      namespaces = allocated_paths.map { |path| path.split("/").first }.uniq
      expect(namespaces.length).to eq(1)
      expect(namespaces.first).to match(/\A\d{13}-[0-9a-f-]{36}\z/)
      expect(allocated_paths).to include(a_string_matching(%r{/[0-9a-f-]{36}\z}))
      try_until_success(timeout: 15) do
        remaining_paths = opfs_files.map { |file| file.fetch("path") }
        expect(remaining_paths.select { |path| namespaces.include?(path.split("/").first) }).to eq(
          [],
        )
      end
    end
    using_session(:alice) do
      wait_for_browser(
        "#{transfers}.some(t => t.id === #{id.to_json} && ['cancelled', 'failed'].includes(t.status))",
      )
    end
  end

  it "deletes an accepted disk-backed transfer on cancellation" do
    abort_accepted_transfer("cancel")
  end

  it "deletes an accepted disk-backed transfer when leaving" do
    abort_accepted_transfer("leave")
  end

  it "deletes a completed disk-backed transfer on dismissal without exporting" do
    join_both
    existing_paths = using_session(:bob) { opfs_files.map { |file| file.fetch("path") } }
    id = using_session(:alice) { send_file("dismiss-completed.dat", [0, 255, 128, 42]) }
    using_session(:bob) do
      expect_status(id, "pending")
      transfer_action("acceptFileTransfer", id)
      expect_status(id, "completed")
      expect(
        opfs_files
          .reject { |file| existing_paths.include?(file.fetch("path")) }
          .map { |file| file.fetch("size") },
      ).to eq([4])
      # Do not call getReceivedFile or Save: neither byte inspection nor export
      # should accidentally enable download-grace retention in this regression.
      transfer_action("dismissFileTransfer", id)
      wait_for_browser("!#{transfers}.some(t => t.id === #{id.to_json})")
      expect_no_opfs_files(existing_paths)
    end
  end

  it "deletes a completed disk-backed transfer when leaving without saving" do
    join_both
    existing_paths = using_session(:bob) { opfs_files.map { |file| file.fetch("path") } }
    id = using_session(:alice) { send_file("leave-completed.dat", [0, 255, 128, 42]) }
    using_session(:bob) do
      expect_status(id, "pending")
      transfer_action("acceptFileTransfer", id)
      expect_status(id, "completed")
      expect(
        opfs_files
          .reject { |file| existing_paths.include?(file.fetch("path")) }
          .map { |file| file.fetch("size") },
      ).to eq([4])
      click_button(I18n.t("js.live.room.leave"))
      expect_no_opfs_files(existing_paths)
      wait_for_browser("!#{transfers}.some(t => t.id === #{id.to_json})")
    end
  end
end
