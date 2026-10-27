import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

function imageFile(id) {
  return {
    id,
    name: `${id}.jpg`,
    type: "image/jpeg",
    size: 1024,
    // Blob#arrayBuffer settles in real time, outside the fake clock
    data: { type: "image/jpeg", arrayBuffer: async () => new ArrayBuffer(8) },
  };
}

module("Unit | Service | media-optimization-worker", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.clock = sinon.useFakeTimers({
      toFake: ["setTimeout", "clearTimeout"],
    });

    this.owner.lookup(
      "service:site-settings"
    ).composer_media_optimization_image_bytes_optimization_threshold = 0;

    this.service = this.owner.lookup("service:media-optimization-worker");
    this.workers = [];
    sinon.stub(window, "Worker").callsFake(() => {
      const worker = { postMessage: sinon.stub(), terminate: sinon.stub() };
      this.workers.push(worker);
      return worker;
    });

    this.optimize = (id) => {
      const state = { settled: false, result: undefined };
      this.service.optimizeImage(imageFile(id)).then((file) => {
        state.settled = true;
        state.result = file;
      });
      return state;
    };
  });

  hooks.afterEach(function () {
    this.service.stopWorker();
    this.clock.restore();
    sinon.restore();
  });

  test("cancelling the only pending file replaces the worker", async function (assert) {
    const stuck = this.optimize("stuck");
    await this.clock.tickAsync(0);

    this.service.cancel("stuck");
    await this.clock.tickAsync(0);
    assert.true(stuck.settled, "the cancelled file settles");
    assert.true(
      this.workers[0].terminate.calledOnce,
      "the worker it may be stuck in is terminated"
    );

    this.optimize("retry");
    await this.clock.tickAsync(0);
    assert.strictEqual(this.workers.length, 2, "a retry gets a fresh worker");
  });

  test("cancelling one of several pending files keeps the worker", async function (assert) {
    const first = this.optimize("first");
    const second = this.optimize("second");
    await this.clock.tickAsync(0);

    this.service.cancel("first");
    await this.clock.tickAsync(0);
    assert.true(first.settled, "the cancelled file settles");
    assert.false(second.settled, "the other file is still being optimized");
    assert.false(this.workers[0].terminate.called, "the worker is kept");
  });

  test("cancelling the remaining file after a late reply allows a fresh retry", async function (assert) {
    this.optimize("cancelled");
    const remaining = this.optimize("remaining");
    await this.clock.tickAsync(0);

    this.service.cancel("cancelled");
    this.workers[0].onmessage({
      data: { type: "skipped", fileId: "cancelled", fileName: "cancelled.jpg" },
    });
    await this.clock.tickAsync(0);

    assert.false(remaining.settled, "the other file is still pending");
    assert.strictEqual(
      this.service.workerPendingCount,
      1,
      "the cancelled file's reply does not decrement the pending count again"
    );
    assert.false(this.workers[0].terminate.called, "the shared worker is kept");

    this.service.cancel("remaining");
    await this.clock.tickAsync(0);
    assert.true(remaining.settled, "the remaining file can be cancelled");
    assert.true(
      this.workers[0].terminate.calledOnce,
      "cancelling the last file terminates the worker"
    );

    const retry = this.optimize("remaining");
    await this.clock.tickAsync(0);
    assert.strictEqual(this.workers.length, 2, "the retry gets a fresh worker");
    this.workers[1].onmessage({
      data: { type: "skipped", fileId: "remaining", fileName: "remaining.jpg" },
    });
    await this.clock.tickAsync(0);
    assert.true(retry.settled, "the retry completes normally");
  });

  test("a read failure after cancellation does not prevent cancelling the next upload", async function (assert) {
    let rejectRead;
    const file = imageFile("cancelled");
    file.data.arrayBuffer = () =>
      new Promise((resolve, reject) => (rejectRead = reject));
    this.service.optimizeImage(file);

    this.service.cancel(file.id);
    await this.clock.tickAsync(0);
    rejectRead(new Error("Read failed"));
    await this.clock.tickAsync(0);

    const next = this.optimize("next");
    await this.clock.tickAsync(0);
    assert.strictEqual(
      this.service.workerPendingCount,
      1,
      "the late read failure does not affect the next upload's pending count"
    );
    this.service.cancel("next");
    await this.clock.tickAsync(0);

    assert.true(next.settled, "the next upload can be cancelled");
    assert.true(
      this.workers[1].terminate.calledOnce,
      "the unresponsive replacement worker is terminated"
    );
  });

  test("a read failure from a stopped worker does not settle a retry of the same file", async function (assert) {
    let rejectRead;
    const file = imageFile("retry");
    file.data.arrayBuffer = () =>
      new Promise((resolve, reject) => (rejectRead = reject));
    this.service.optimizeImage(file);

    this.service.stopWorker();
    await this.clock.tickAsync(0);
    const retry = this.optimize(file.id);
    await this.clock.tickAsync(0);
    rejectRead(new Error("Read failed"));
    await this.clock.tickAsync(0);

    assert.false(retry.settled, "the retry keeps waiting for its own result");

    this.workers[1].onmessage({
      data: { type: "skipped", fileId: file.id, fileName: file.name },
    });
    await this.clock.tickAsync(0);
    assert.true(retry.settled, "the retry completes with its own result");
  });

  test("closing the composer settles in-flight optimizations", async function (assert) {
    const pending = this.optimize("pending");
    await this.clock.tickAsync(0);

    this.owner.lookup("service:app-events").trigger("composer:closed");
    await this.clock.tickAsync(0);
    assert.true(pending.settled, "the upload is not left hanging");
  });
});
