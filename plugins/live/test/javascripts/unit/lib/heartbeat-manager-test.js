import { settled, waitUntil } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import HeartbeatManager from "discourse/plugins/live/discourse/lib/live/heartbeat-manager";

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

module("Live | Unit | Lib | heartbeat-manager", function (hooks) {
  setupTest(hooks);

  test("keeps beating after a beat that never gets a response", async function (assert) {
    let requests = 0;
    // Async pretender handlers stay pending until resolved manually.
    pretender.post(
      "/live/rooms/1/heartbeat",
      () => {
        requests++;
        return response(204, {});
      },
      true
    );

    const manager = new HeartbeatManager({
      isActiveRoom: () => true,
      buildPayload: () => ({}),
      onExpelled: () => assert.step("expelled"),
      intervalMs: 20,
      timeoutMs: 20,
    });

    manager.start(1);
    await wait(300);
    manager.stop(1);

    assert.true(requests > 1, "later beats are sent after the stalled one");
    assert.verifySteps([], "a stalled beat is not treated as an expulsion");
  });

  test("reports an expulsion when the server rejects the session", async function (assert) {
    pretender.post("/live/rooms/1/heartbeat", () => response(403, {}));

    const manager = new HeartbeatManager({
      isActiveRoom: () => true,
      buildPayload: () => ({}),
      onExpelled: (roomId) => {
        assert.step(`expelled ${roomId}`);
        manager.stop(roomId);
      },
      intervalMs: 20,
    });

    manager.start(1);
    await wait(200);
    manager.stop(1);

    assert.verifySteps(["expelled 1"]);
  });

  test("ignores a rejection of a beat sent before a restart", async function (assert) {
    pretender.post("/live/rooms/1/heartbeat", () => response(404, {}), true);
    const beats = () =>
      pretender.handledRequests.filter((request) =>
        request.url.endsWith("/heartbeat")
      );

    const manager = new HeartbeatManager({
      isActiveRoom: () => true,
      buildPayload: () => ({}),
      onExpelled: (roomId) => {
        assert.step(`expelled ${roomId}`);
        manager.stop(roomId);
      },
      intervalMs: 20,
      timeoutMs: 1000,
    });

    manager.start(1);
    await waitUntil(() => beats().length === 1);
    manager.stop(1);
    manager.start(1);
    await waitUntil(() => beats().length === 2);

    const [staleBeat, currentBeat] = beats();
    pretender.resolve(staleBeat);
    pretender.resolve(currentBeat);
    await settled();

    assert.verifySteps(
      ["expelled 1"],
      "expels only on the current beat's rejection"
    );
  });
});
