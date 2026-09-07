import { module, test } from "qunit";
import SignalingManager from "discourse/plugins/voice/discourse/lib/voice/signaling";

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function deferred() {
  let resolve;
  let reject;

  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });

  return { promise, resolve, reject };
}

module("Voice | Unit | Lib | signaling", function () {
  test("clearForPeer drops unsent HTTP-batched signals for destroyed peers", async function (assert) {
    assert.timeout(1000);

    let requests = 0;

    const manager = new SignalingManager({
      isActiveRoom: () => true,
      hasPeer: () => true,
      httpBatchDelayMs: 5,
      requestSignals: async () => {
        requests++;
      },
    });

    const send = manager.send(1, 2, { type: "offer", sdp: "v=0" });
    await Promise.resolve();
    manager.clearForPeer(1, 2);

    await send;
    await wait(50);

    assert.strictEqual(
      requests,
      0,
      "does not send signals that were cleared during teardown"
    );

    manager.destroy();
  });

  test("flushes a recipient's batch early once it reaches the event cap", async function (assert) {
    assert.timeout(2000);

    const payloads = [];

    const manager = new SignalingManager({
      isActiveRoom: () => true,
      hasPeer: () => true,
      // Far beyond the test's patience: only the early flush can send.
      httpBatchDelayMs: 5000,
      requestSignals: async (roomId, payload) => {
        payloads.push(payload);
      },
    });

    const sends = [];
    for (let i = 0; i < 20; i++) {
      sends.push(manager.send(1, 2, { type: "offer", sdp: `sdp-${i}` }));
    }
    await Promise.all(sends);

    assert.strictEqual(
      payloads.length,
      1,
      "sends without waiting for the batch timer"
    );
    assert.strictEqual(
      payloads[0].events.length,
      20,
      "carries the whole accumulated batch"
    );

    manager.destroy();
  });

  test("each HTTP flush only settles the signals it actually sent", async function (assert) {
    assert.timeout(2000);

    const requests = [];
    let firstResolved = false;
    let secondResolved = false;

    const manager = new SignalingManager({
      isActiveRoom: () => true,
      hasPeer: () => true,
      httpBatchDelayMs: 5,
      requestSignals: () => {
        const request = deferred();
        requests.push(request);
        return request.promise;
      },
    });

    const firstSend = manager
      .send(1, 2, { type: "offer", sdp: "first" })
      .then(() => {
        firstResolved = true;
      });

    await wait(50);

    assert.strictEqual(requests.length, 1, "starts the first HTTP flush");

    const secondSend = manager
      .send(1, 3, {
        type: "offer",
        sdp: "second",
      })
      .then(() => {
        secondResolved = true;
      });

    await wait(50);

    assert.strictEqual(
      requests.length,
      2,
      "starts a second HTTP flush for signals queued during the first one"
    );

    requests[0].resolve();
    await firstSend;

    assert.true(firstResolved, "resolves the first send after the first flush");
    assert.false(
      secondResolved,
      "does not resolve later sends when an earlier flush completes"
    );

    requests[1].resolve();
    await secondSend;

    assert.true(
      secondResolved,
      "resolves the second send after its own flush completes"
    );

    manager.destroy();
  });
});
