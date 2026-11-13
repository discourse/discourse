import { waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import FileTransferManager, {
  CHUNK_SIZE,
  MAX_FILE_SIZE,
} from "discourse/plugins/live/discourse/lib/live/file-transfer-manager";

class Channel {
  readyState = "open";
  bufferedAmount = 0;
  sent = [];

  send(data) {
    this.sent.push(data);
    queueMicrotask(() => this.remote?.onmessage?.({ data }));
  }

  close() {
    this.readyState = "closed";
  }
}

module("Live | Unit | Lib | file-transfer-manager", function (hooks) {
  hooks.beforeEach(function () {
    this.eligible = true;
    this.sender = new FileTransferManager({ isEligible: () => this.eligible });
    this.receiver = new FileTransferManager({
      isEligible: () => this.eligible,
    });
    this.a = new Channel();
    this.b = new Channel();
    this.a.remote = this.b;
    this.b.remote = this.a;
    this.sender.attach(1, 2, this.a);
    this.receiver.attach(1, 1, this.b);
    this.offer = async (contents = "hello") => {
      const id = this.sender.send(1, 2, new File([contents], "example.txt"));
      await Promise.resolve();
      return id;
    };
    this.message = (channel, type, id, extra = {}) =>
      channel.onmessage({ data: JSON.stringify({ type, id, ...extra }) });
  });
  hooks.afterEach(function () {
    this.sender.destroy();
    this.receiver.destroy();
  });

  test("waits for explicit acceptance; chunks bytes and completes only after acknowledgement", async function (assert) {
    const contents = "x".repeat(CHUNK_SIZE * 2 + 7);
    const id = await this.offer(contents);
    assert.strictEqual(this.sender.transfers[0].status, "waiting");
    assert.strictEqual(this.receiver.transfers[0].status, "pending");
    assert.strictEqual(
      this.a.sent.length,
      1,
      "offer only; no bytes before acceptance"
    );
    this.b.remote = null; // withhold receiver acknowledgement
    this.receiver.accept(id);
    this.message(this.a, "accept", id);
    await waitUntil(() => this.receiver.transfers[0].status === "completed");
    assert.strictEqual(
      this.sender.transfers[0].status,
      "transferring",
      "still awaits ack"
    );
    assert.strictEqual(await this.receiver.transfers[0].blob.text(), contents);
    assert.strictEqual(
      this.receiver.transfers[0].blob.type,
      "application/octet-stream"
    );
    const frames = this.a.sent.filter((data) => data instanceof ArrayBuffer);
    assert.deepEqual(
      frames.map((frame) => frame.byteLength),
      [CHUNK_SIZE + 36, CHUNK_SIZE + 36, 43]
    );
    this.message(this.a, "complete", id);
    assert.strictEqual(this.sender.transfers[0].status, "completed");
    assert.strictEqual(this.sender.transfers[0].progress, 1);
    assert.strictEqual(this.sender.transfers[0].blob, null);
  });

  test("zero byte files still require acceptance and complete with an empty Blob", async function (assert) {
    const id = await this.offer("");
    this.receiver.accept(id);
    await waitUntil(() => this.sender.transfers[0].status === "completed");
    assert.strictEqual(this.receiver.transfers[0].blob.size, 0);
    assert.strictEqual(this.receiver.transfers[0].progress, 1);
    assert.false(this.a.sent.some((data) => data instanceof ArrayBuffer));
  });

  test("reject, cancel, dismiss and leave release transfers", async function (assert) {
    let id = await this.offer();
    this.receiver.reject(id);
    await Promise.resolve();
    assert.strictEqual(this.sender.transfers[0].status, "rejected");
    this.sender.dismiss(id);
    this.receiver.dismiss(id);
    id = await this.offer();
    this.sender.cancel(id);
    await Promise.resolve();
    assert.strictEqual(this.receiver.transfers[0].status, "cancelled");
    this.sender.leave(1);
    this.receiver.leave(1);
    assert.deepEqual(this.sender.transfers, []);
    assert.deepEqual(this.receiver.transfers, []);
    assert.strictEqual(this.a.readyState, "closed");
  });

  test("backpressure stops reads and cancellation stops the pump", async function (assert) {
    const id = await this.offer();
    this.a.bufferedAmount = 1024 * 1024;
    this.receiver.accept(id);
    await Promise.resolve();
    assert.false(this.a.sent.some((data) => data instanceof ArrayBuffer));
    this.sender.cancel(id);
    this.a.bufferedAmount = 0;
    await new Promise((resolve) => setTimeout(resolve, 40));
    assert.false(this.a.sent.some((data) => data instanceof ArrayBuffer));
    assert.strictEqual(this.sender.transfers[0].status, "cancelled");
  });

  test("disabled or non-participant eligibility blocks send and incoming offers", async function (assert) {
    this.eligible = false;
    assert.false(this.sender.canSend(1, 2));
    assert.throws(() => this.sender.send(1, 2, new File(["x"], "x.txt")));
    this.message(this.b, "offer", crypto.randomUUID(), {
      name: "x.txt",
      size: 1,
    });
    assert.deepEqual(this.receiver.transfers, []);
    assert.strictEqual(this.b.readyState, "closed");
  });

  test("validates metadata and bounds pending incoming offers globally", function (assert) {
    for (const metadata of [
      { name: "../bad", size: 1 },
      { name: "a\\b", size: 1 },
      { name: "", size: 1 },
      { name: "x".repeat(256), size: 1 },
      { name: "x\u0000", size: 1 },
      { name: "x", size: -1 },
      { name: "x", size: 1.5 },
      { name: "x", size: MAX_FILE_SIZE + 1 },
    ]) {
      this.message(this.b, "offer", crypto.randomUUID(), metadata);
    }
    assert.strictEqual(this.receiver.transfers.length, 0);
    for (let userId = 10; userId < 16; userId++) {
      const channel = new Channel();
      this.receiver.attach(1, userId, channel);
      this.message(channel, "offer", crypto.randomUUID(), {
        name: "valid.txt",
        size: 1,
      });
    }
    assert.strictEqual(this.receiver.transfers.length, 4);
  });

  test("aggregate accepted receive reservations cannot exceed 200 MiB", function (assert) {
    for (let userId = 10; userId < 13; userId++) {
      const channel = new Channel();
      this.receiver.attach(1, userId, channel);
      const id = crypto.randomUUID();
      this.message(channel, "offer", id, {
        name: "large.bin",
        size: MAX_FILE_SIZE,
      });
      this.receiver.accept(id);
    }
    assert.deepEqual(
      this.receiver.transfers.map((t) => t.status),
      ["transferring", "transferring", "rejected"]
    );
  });

  test("preaccept binary fails transfer and closes channel; unrequested bytes are not retained", async function (assert) {
    this.b.onmessage({ data: new ArrayBuffer(40) });
    assert.deepEqual(this.receiver.transfers, []);
    const id = await this.offer();
    const frame = new Uint8Array(37);
    frame.set(new TextEncoder().encode(id));
    this.b.onmessage({ data: frame.buffer });
    assert.strictEqual(this.receiver.transfers[0].status, "failed");
    assert.strictEqual(this.b.readyState, "closed");
    assert.strictEqual(this.receiver.transfers[0].blob, null);
  });

  test("malformed controls and early completion cannot create a Blob", async function (assert) {
    const id = await this.offer();
    this.receiver.accept(id);
    this.message(this.b, "complete", id);
    assert.strictEqual(this.receiver.transfers[0].status, "failed");
    assert.strictEqual(this.receiver.transfers[0].blob, null);
    assert.strictEqual(this.b.readyState, "closed");
  });

  test("simultaneous offers resolve as busy rejection without transferring bytes", async function (assert) {
    this.sender.send(1, 2, new File(["a"], "a.txt"));
    this.receiver.send(1, 1, new File(["b"], "b.txt"));
    await Promise.resolve();
    await Promise.resolve();
    assert.strictEqual(this.sender.transfers[0].status, "rejected");
    assert.strictEqual(this.receiver.transfers[0].status, "rejected");
    assert.true(this.sender.canSend(1, 2));
  });

  test("backpressure resumes once the channel buffer drains", async function (assert) {
    const id = await this.offer("resumed");
    this.a.bufferedAmount = 1024 * 1024;
    this.receiver.accept(id);
    await Promise.resolve();
    assert.false(this.a.sent.some((data) => data instanceof ArrayBuffer));
    this.a.bufferedAmount = 0;
    await waitUntil(() => this.sender.transfers[0].status === "completed");
    assert.strictEqual(await this.receiver.transfers[0].blob.text(), "resumed");
  });

  test("completed receive Blobs count toward the global reservation budget", function (assert) {
    const id = crypto.randomUUID();
    this.message(this.b, "offer", id, { name: "retained", size: 1 });
    this.receiver.accept(id);
    const frame = new Uint8Array(37);
    frame.set(new TextEncoder().encode(id));
    this.b.onmessage({ data: frame.buffer });
    this.message(this.b, "complete", id);
    for (let userId = 10; userId < 12; userId++) {
      const channel = new Channel();
      this.receiver.attach(1, userId, channel);
      const pendingId = crypto.randomUUID();
      this.message(channel, "offer", pendingId, {
        name: "large",
        size: MAX_FILE_SIZE,
      });
      this.receiver.accept(pendingId);
    }
    assert.deepEqual(
      this.receiver.transfers.map((entry) => entry.status),
      ["completed", "transferring", "rejected"]
    );
    this.receiver.dismiss(id);
    assert.false(this.receiver.transfers.some((entry) => entry.blob));
  });

  test("a failed completion acknowledgement cannot become completed or retain a Blob", async function (assert) {
    const id = await this.offer("");
    this.receiver.accept(id);
    this.b.send = () => {
      throw new Error("closed");
    };
    await waitUntil(() => this.receiver.transfers[0].status === "failed");
    assert.strictEqual(this.receiver.transfers[0].blob, null);
    assert.notStrictEqual(this.sender.transfers[0].status, "completed");
  });

  test("oversized and malformed controls close the channel without retaining entries", function (assert) {
    for (const data of [
      "{",
      "x".repeat(2049),
      "null",
      JSON.stringify({
        type: "offer",
        id: [crypto.randomUUID()],
        name: "x",
        size: 1,
      }),
    ]) {
      const channel = new Channel();
      this.receiver.attach(1, 9, channel);
      channel.onmessage({ data });
      assert.strictEqual(channel.readyState, "closed");
      assert.deepEqual(this.receiver.transfers, []);
    }
  });

  test("receive overflow and oversized binary frames fail without retaining bytes", function (assert) {
    for (const length of [38, CHUNK_SIZE + 37]) {
      const channel = new Channel();
      const id = crypto.randomUUID();
      this.receiver.attach(1, 9, channel);
      this.message(channel, "offer", id, { name: "x", size: 1 });
      this.receiver.accept(id);
      const frame = new Uint8Array(length);
      frame.set(new TextEncoder().encode(id));
      channel.onmessage({ data: frame.buffer });
      assert.strictEqual(this.receiver.transfers.at(-1).status, "failed");
      assert.strictEqual(this.receiver.transfers.at(-1).blob, null);
      assert.strictEqual(channel.readyState, "closed");
    }
  });

  test("stale transfer frames cannot contaminate a later accepted transfer", function (assert) {
    const oldId = crypto.randomUUID();
    this.message(this.b, "offer", oldId, { name: "old", size: 1 });
    this.receiver.accept(oldId);
    this.receiver.cancel(oldId);
    const id = crypto.randomUUID();
    this.message(this.b, "offer", id, { name: "new", size: 0 });
    this.receiver.accept(id);
    const frame = new Uint8Array(37);
    frame.set(new TextEncoder().encode(oldId));
    this.b.onmessage({ data: frame.buffer });
    this.message(this.b, "complete", id);
    assert.strictEqual(this.receiver.transfers[1].status, "completed");
    assert.strictEqual(this.receiver.transfers[1].blob.size, 0);
    this.receiver.dismiss(id);
    assert.false(this.receiver.transfers.some((entry) => entry.blob));
  });

  test("stale cancelled frames leave a new pending offer intact, but matching preaccept bytes close it", function (assert) {
    const oldId = crypto.randomUUID();
    this.message(this.b, "offer", oldId, { name: "old", size: 1 });
    this.receiver.accept(oldId);
    this.receiver.cancel(oldId);
    const id = crypto.randomUUID();
    this.message(this.b, "offer", id, { name: "new", size: 1 });
    const frame = new Uint8Array(37);
    frame.set(new TextEncoder().encode(oldId));
    this.b.onmessage({ data: frame.buffer });
    assert.strictEqual(this.receiver.transfers[1].status, "pending");
    assert.strictEqual(this.receiver.transfers[1].progress, 0);
    assert.strictEqual(this.receiver.transfers[1].blob, null);
    assert.strictEqual(
      this.b.readyState,
      "open",
      "stale bytes do not close the channel"
    );
    frame.set(new TextEncoder().encode(id));
    this.b.onmessage({ data: frame.buffer });
    assert.strictEqual(this.receiver.transfers[1].status, "failed");
    assert.strictEqual(this.receiver.transfers[1].blob, null);
    assert.strictEqual(
      this.b.readyState,
      "closed",
      "matching bytes still require acceptance"
    );
  });

  test("retained history is bounded even when a peer floods offers", function (assert) {
    for (let i = 0; i < 110; i++) {
      const id = crypto.randomUUID();
      this.message(this.b, "offer", id, { name: "x", size: 0 });
      this.receiver.reject(id);
    }
    assert.strictEqual(this.receiver.transfers.length, 100);
    this.receiver.dismiss(this.receiver.transfers[0].id);
    const id = crypto.randomUUID();
    this.message(this.b, "offer", id, { name: "x", size: 0 });
    assert.strictEqual(this.receiver.transfers.length, 100);
    assert.strictEqual(this.receiver.transfers.at(-1).status, "pending");
  });

  test("channel readiness changes invalidate reactive availability and close cleans active state", async function (assert) {
    this.a.readyState = "connecting";
    assert.false(this.sender.canSend(1, 2));
    const revision = this.sender.channelsRevision;
    this.a.readyState = "open";
    this.a.onopen();
    assert.true(this.sender.channelsRevision > revision);
    assert.true(this.sender.canSend(1, 2));
    await this.offer();
    this.a.onclose();
    assert.strictEqual(this.sender.transfers[0].status, "failed");
    assert.false(this.sender.canSend(1, 2));
    assert.strictEqual(this.a.onopen, null);
    assert.strictEqual(this.a.onmessage, null);
  });

  test("timeout fails pending requests and disconnect fails active transfers", async function (assert) {
    this.receiver.destroy();
    this.receiver = new FileTransferManager({
      isEligible: () => true,
      timeoutMs: 10,
    });
    this.b = new Channel();
    this.receiver.attach(1, 1, this.b);
    this.message(this.b, "offer", crypto.randomUUID(), { name: "x", size: 1 });
    await waitUntil(() => this.receiver.transfers[0].status === "failed");
    assert.strictEqual(
      this.receiver.transfers[0].error,
      "File transfer timed out"
    );
    await this.offer();
    this.sender.disconnect(1, 2);
    assert.strictEqual(this.sender.transfers[0].status, "failed");
    this.receiver.destroy();
    assert.deepEqual(this.receiver.transfers, []);
  });
});
