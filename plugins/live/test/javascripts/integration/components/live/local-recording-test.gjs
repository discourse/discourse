import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DialogHolder from "discourse/dialog-holder/components/dialog-holder";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import LiveLocalRecordingMenuItem from "discourse/plugins/live/discourse/components/live/local-recording-menu-item";
import LiveRecordingBadge from "discourse/plugins/live/discourse/components/live/recording-badge";

class LiveWebrtcStub extends Service {
  @tracked recordingRoomId = null;

  screenShareSupported = false;
  startCalls = [];

  get localRecordingBusy() {
    return !!this.recordingRoomId;
  }

  isActiveRoom() {
    return true;
  }

  isLivekitRoom() {
    return false;
  }

  isRecordingLocally(roomId) {
    return this.recordingRoomId === roomId;
  }

  startLocalRecording(roomId, displayStream = null) {
    this.startCalls.push({ roomId, displayStream });
    this.recordingRoomId = roomId;
  }

  stopLocalRecording() {
    this.recordingRoomId = null;
  }
}

const RECORD_BUTTON = ".live-local-recording-toggle";

const MenuItem = <template>
  <DialogHolder />
  <DDropdownMenu as |dropdown|>
    <LiveLocalRecordingMenuItem @item={{dropdown.item}} @room={{@room}} />
  </DDropdownMenu>
</template>;

module("Integration | Component | live/local-recording", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser = logIn(this.owner);
    this.currentUser.set("live_can_record_locally", true);

    this.owner.unregister("service:live-webrtc");
    this.owner.register("service:live-webrtc", LiveWebrtcStub);
    this.liveWebrtc = this.owner.lookup("service:live-webrtc");

    this.room = { id: 1, slug: "standup", active_participants: [] };
  });

  test("hides the record entry without the permission", async function (assert) {
    this.currentUser.set("live_can_record_locally", false);
    const room = this.room;

    await render(<template><MenuItem @room={{room}} /></template>);

    assert.dom(RECORD_BUTTON).doesNotExist();
  });

  test("records audio only when the browser can't capture video", async function (assert) {
    const room = this.room;
    await render(<template><MenuItem @room={{room}} /></template>);

    await click(RECORD_BUTTON);
    assert.deepEqual(this.liveWebrtc.startCalls, [
      { roomId: 1, displayStream: null },
    ]);
    assert.dom(RECORD_BUTTON).hasClass("--recording");

    await click(RECORD_BUTTON);
    assert.dom(RECORD_BUTTON).doesNotHaveClass("--recording");
  });

  test("records the tab when the capture succeeds", async function (assert) {
    const displayStream = { id: "tab" };
    this.liveWebrtc.screenShareSupported = true;
    sinon
      .stub(navigator.mediaDevices, "getDisplayMedia")
      .resolves(displayStream);
    const room = this.room;

    await render(<template><MenuItem @room={{room}} /></template>);
    await click(RECORD_BUTTON);

    assert.deepEqual(this.liveWebrtc.startCalls, [
      { roomId: 1, displayStream },
    ]);
  });

  test("offers an audio-only recording when the capture fails", async function (assert) {
    this.liveWebrtc.screenShareSupported = true;
    sinon
      .stub(navigator.mediaDevices, "getDisplayMedia")
      .rejects(new DOMException("denied", "NotAllowedError"));
    const room = this.room;

    await render(<template><MenuItem @room={{room}} /></template>);
    await click(RECORD_BUTTON);

    assert
      .dom(".dialog-body")
      .hasText(
        "The call video couldn't be captured. Record audio only instead?"
      );
    assert.deepEqual(this.liveWebrtc.startCalls, []);

    await click(".dialog-footer .btn-primary");
    assert.deepEqual(this.liveWebrtc.startCalls, [
      { roomId: 1, displayStream: null },
    ]);
  });

  test("the badge covers server and local recordings", async function (assert) {
    const room = {
      id: 1,
      active_participants: [
        { id: 2, username: "alice", is_recording_locally: true },
        { id: 3, username: "bob" },
      ],
    };
    await render(<template><LiveRecordingBadge @room={{room}} /></template>);

    assert
      .dom(".live-recording-badge")
      .hasAttribute("title", "alice is recording this call to their device");

    this.liveWebrtc.recordingRoomId = 1;
    await settled();
    assert
      .dom(".live-recording-badge")
      .hasAttribute(
        "title",
        "You're recording this call to your device\nalice is recording this call to their device"
      );
  });

  test("the badge stays hidden when nobody is recording", async function (assert) {
    const room = { id: 1, active_participants: [{ id: 3, username: "bob" }] };
    await render(<template><LiveRecordingBadge @room={{room}} /></template>);

    assert.dom(".live-recording-badge").doesNotExist();
  });
});
