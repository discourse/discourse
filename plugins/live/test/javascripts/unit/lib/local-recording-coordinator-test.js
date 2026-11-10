import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import LocalRecordingCoordinator from "discourse/plugins/live/discourse/lib/live/local-recording-coordinator";

module("Live | Unit | Lib | local-recording-coordinator", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.activeRoomId = 1;
    this.coordinator = new LocalRecordingCoordinator({
      getCurrentUserId: () => 1,
      getParticipantSessionId: () => "session",
      getRoom: () => ({ slug: "room" }),
      isActiveRoom: (roomId) => roomId === this.activeRoomId,
      getAudioTracks: () => [],
      setParticipantRecording: () => {},
      showNotice: () => {},
      showError: () => {},
    });
  });

  hooks.afterEach(function () {
    this.coordinator.destroy();
  });

  test("trackRecorders announces only recorders who start after the baseline", function (assert) {
    const alice = { id: 2, username: "alice", is_recording_locally: true };
    const bob = { id: 3, username: "bob" };
    const self = { id: 1, username: "me", is_recording_locally: true };

    assert.deepEqual(
      this.coordinator.trackRecorders(1, [alice, bob, self]),
      [],
      "the first roster only sets the baseline"
    );

    assert.deepEqual(
      this.coordinator.trackRecorders(1, [
        alice,
        { ...bob, is_recording_locally: true },
        self,
      ]),
      ["bob"],
      "announces a new recorder, never the current user"
    );

    assert.deepEqual(
      this.coordinator.trackRecorders(1, [alice, bob, self]),
      [],
      "a recorder stopping is not announced"
    );

    assert.deepEqual(
      this.coordinator.trackRecorders(1, [
        alice,
        { ...bob, is_recording_locally: true },
      ]),
      ["bob"],
      "a recorder restarting is announced again"
    );

    this.coordinator.forgetRoom(1);
    assert.deepEqual(
      this.coordinator.trackRecorders(1, [
        alice,
        { ...bob, is_recording_locally: true },
      ]),
      [],
      "forgetting a room resets its baseline"
    );
  });

  test("start releases the capture when the room isn't the active call", async function (assert) {
    let stopped = false;
    const displayStream = {
      getTracks: () => [{ stop: () => (stopped = true) }],
    };

    await this.coordinator.start(2, displayStream);

    assert.true(stopped, "stops the display capture");
    assert.false(this.coordinator.busy);
    assert.false(this.coordinator.isRecording(2));
  });
});
