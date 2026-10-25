import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { WORKER_STALL_TIMEOUT_MS } from "discourse/services/media-optimization-worker";

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

  test("uploads the original file when the worker stops responding", async function (assert) {
    const stuck = this.optimize("stuck");

    await this.clock.tickAsync(WORKER_STALL_TIMEOUT_MS - 1);
    assert.false(stuck.settled, "waits for the worker until the timeout");

    await this.clock.tickAsync(1);
    assert.true(stuck.settled, "gives up on the file after the timeout");
    assert.strictEqual(stuck.result, undefined, "the file is left unoptimized");
    assert.true(
      this.workers[0].terminate.calledOnce,
      "the stuck worker is terminated"
    );

    this.optimize("next");
    await this.clock.tickAsync(0);
    assert.strictEqual(
      this.workers.length,
      2,
      "a later file gets a fresh worker"
    );
  });

  test("sending more work does not extend a stuck worker's deadline", async function (assert) {
    const first = this.optimize("first");
    await this.clock.tickAsync(WORKER_STALL_TIMEOUT_MS / 2);
    const second = this.optimize("second");

    await this.clock.tickAsync(WORKER_STALL_TIMEOUT_MS / 2);
    assert.true(first.settled, "the first file times out on schedule");
    assert.true(second.settled, "the second file is not left behind it");
  });

  test("times out a file that follows a worker error", async function (assert) {
    this.optimize("broken");
    await this.clock.tickAsync(0);
    this.workers[0].onmessage({
      data: { type: "error", fileId: "broken", fileName: "broken.jpg" },
    });

    const stuck = this.optimize("stuck");
    await this.clock.tickAsync(WORKER_STALL_TIMEOUT_MS);
    assert.true(stuck.settled, "the next file isn't left waiting forever");
  });

  test("keeps waiting while the worker is still reporting back", async function (assert) {
    this.optimize("first");
    const second = this.optimize("second");

    await this.clock.tickAsync(WORKER_STALL_TIMEOUT_MS - 1);
    this.workers[0].onmessage({
      data: { type: "skipped", fileId: "first", fileName: "first.jpg" },
    });

    await this.clock.tickAsync(WORKER_STALL_TIMEOUT_MS - 1);
    assert.false(
      second.settled,
      "the timeout restarts whenever the worker responds"
    );

    await this.clock.tickAsync(1);
    assert.true(second.settled, "times out once the worker goes quiet");
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

  test("a late reply for a cancelled file preserves the remaining file's timeout", async function (assert) {
    this.optimize("cancelled");
    const stuck = this.optimize("stuck");
    await this.clock.tickAsync(0);

    this.service.cancel("cancelled");
    await this.clock.tickAsync(WORKER_STALL_TIMEOUT_MS / 2);
    this.workers[0].onmessage({
      data: { type: "skipped", fileId: "cancelled", fileName: "cancelled.jpg" },
    });

    assert.false(stuck.settled, "the remaining file is still being optimized");

    await this.clock.tickAsync(WORKER_STALL_TIMEOUT_MS / 2);
    assert.true(stuck.settled, "the remaining file times out on schedule");
    assert.strictEqual(stuck.result, undefined, "the file is left unoptimized");
    assert.true(
      this.workers[0].terminate.calledOnce,
      "the unresponsive worker is terminated"
    );
  });

  test("a read failure after cancellation preserves the next upload's timeout", async function (assert) {
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
    await this.clock.tickAsync(WORKER_STALL_TIMEOUT_MS);

    assert.true(next.settled, "the next upload times out");
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

    await this.clock.tickAsync(WORKER_STALL_TIMEOUT_MS);
    assert.true(retry.settled, "the retry times out normally");
  });

  test("closing the composer settles in-flight optimizations", async function (assert) {
    const pending = this.optimize("pending");
    await this.clock.tickAsync(0);

    this.owner.lookup("service:app-events").trigger("composer:closed");
    await this.clock.tickAsync(0);
    assert.true(pending.settled, "the upload is not left hanging");
  });
});
