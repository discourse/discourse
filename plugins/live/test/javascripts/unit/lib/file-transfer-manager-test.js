import { waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  DEFAULT_MAX_FILE_SIZE,
  MEBIBYTE,
} from "discourse/plugins/live/discourse/lib/live/file-transfer-limits";
import FileTransferManager, {
  CHUNK_SIZE,
  RECEIVE_WINDOW,
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

// Unit tests explicitly inject memory storage; production never falls back to it.
class TestSink {
  chunks = [];
  discarded = false;

  async write(chunk) {
    this.chunks.push(chunk);
  }

  async finish() {
    return { size: (await this.getFile()).size };
  }

  async getFile() {
    return new File(this.chunks, "received", {
      type: "application/octet-stream",
    });
  }

  async discard() {
    this.discarded = true;
    this.chunks = [];
  }
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((yes, no) => {
    resolve = yes;
    reject = no;
  });
  return { promise, resolve, reject };
}

module("Live | Unit | Lib | file-transfer-manager", function (hooks) {
  hooks.beforeEach(function () {
    this.eligible = true;
    this.sinks = [];
    this.openSink = async () => {
      const sink = new TestSink();
      this.sinks.push(sink);
      return sink;
    };
    this.sender = new FileTransferManager({ isEligible: () => this.eligible });
    this.receiver = new FileTransferManager({
      isEligible: () => this.eligible,
      openReceiveSink: this.openSink,
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
    const send = this.b.send.bind(this.b);
    this.b.send = (data) => {
      if (typeof data === "string" && JSON.parse(data).type === "complete") {
        return;
      }
      send(data);
    };
    await this.receiver.accept(id);
    await waitUntil(() => this.receiver.transfers[0].status === "completed");
    assert.strictEqual(
      this.sender.transfers[0].status,
      "transferring",
      "still awaits ack"
    );
    assert.strictEqual(
      await (
        await this.receiver.getReceivedFile(this.receiver.transfers[0].id)
      ).text(),
      contents
    );
    assert.strictEqual(
      (await this.receiver.getReceivedFile(id)).type,
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
    assert.false(this.sender.transfers[0].hasFile);
  });

  test("zero byte files still require acceptance and expose an empty disk File", async function (assert) {
    const id = await this.offer("");
    await this.receiver.accept(id);
    await waitUntil(() => this.sender.transfers[0].status === "completed");
    assert.strictEqual((await this.receiver.getReceivedFile(id)).size, 0);
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
    this.a.bufferedAmount = RECEIVE_WINDOW + 1;
    await this.receiver.accept(id);
    await Promise.resolve();
    assert.false(this.a.sent.some((data) => data instanceof ArrayBuffer));
    this.sender.cancel(id);
    this.a.bufferedAmount = 0;
    await new Promise((resolve) => setTimeout(resolve, 40));
    assert.false(this.a.sent.some((data) => data instanceof ArrayBuffer));
    assert.strictEqual(this.sender.transfers[0].status, "cancelled");
  });

  test("control-channel congestion fails closed instead of queuing cancellation", async function (assert) {
    const id = await this.offer();
    this.a.bufferedAmount = 1024 * 1024;
    await this.receiver.accept(id);
    this.sender.cancel(id);
    assert.strictEqual(this.sender.transfers[0].status, "failed");
    assert.strictEqual(
      this.sender.transfers[0].error,
      "Data channel unavailable"
    );
    assert.strictEqual(this.a.readyState, "closed");
    assert.false(this.a.sent.some((data) => data instanceof ArrayBuffer));
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

  test("validates metadata and bounds pending incoming offers globally", async function (assert) {
    for (const metadata of [
      { name: "../bad", size: 1 },
      { name: "a\\b", size: 1 },
      { name: "", size: 1 },
      { name: "x".repeat(256), size: 1 },
      { name: "x\u0000", size: 1 },
      { name: "x", size: -1 },
      { name: "x", size: 1.5 },
      { name: "x", size: DEFAULT_MAX_FILE_SIZE + 1 },
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

  test("aggregate accepted receive reservations cannot exceed 200 MiB", async function (assert) {
    for (let userId = 10; userId < 13; userId++) {
      const channel = new Channel();
      this.receiver.attach(1, userId, channel);
      const id = crypto.randomUUID();
      this.message(channel, "offer", id, {
        name: "large.bin",
        size: DEFAULT_MAX_FILE_SIZE,
      });
      await this.receiver.accept(id);
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
    assert.false(this.receiver.transfers[0].hasFile);
  });

  test("malformed controls and early completion cannot expose a File", async function (assert) {
    const id = await this.offer();
    await this.receiver.accept(id);
    this.message(this.b, "complete", id);
    assert.strictEqual(this.receiver.transfers[0].status, "failed");
    assert.false(this.receiver.transfers[0].hasFile);
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
    this.a.bufferedAmount = RECEIVE_WINDOW + 1;
    await this.receiver.accept(id);
    await Promise.resolve();
    assert.false(this.a.sent.some((data) => data instanceof ArrayBuffer));
    this.a.bufferedAmount = 0;
    await waitUntil(() => this.sender.transfers[0].status === "completed");
    assert.strictEqual(
      await (
        await this.receiver.getReceivedFile(this.receiver.transfers[0].id)
      ).text(),
      "resumed"
    );
  });

  test("completed receive files count toward the global disk reservation budget", async function (assert) {
    const id = crypto.randomUUID();
    this.message(this.b, "offer", id, { name: "retained", size: 1 });
    await this.receiver.accept(id);
    const frame = new Uint8Array(37);
    frame.set(new TextEncoder().encode(id));
    this.b.onmessage({ data: frame.buffer });
    await waitUntil(() =>
      this.b.sent.some(
        (data) => typeof data === "string" && JSON.parse(data).type === "ack"
      )
    );
    this.message(this.b, "complete", id);
    await waitUntil(() => this.receiver.transfers[0].status === "completed");
    for (let userId = 10; userId < 12; userId++) {
      const channel = new Channel();
      this.receiver.attach(1, userId, channel);
      const pendingId = crypto.randomUUID();
      this.message(channel, "offer", pendingId, {
        name: "large",
        size: DEFAULT_MAX_FILE_SIZE,
      });
      await this.receiver.accept(pendingId);
    }
    assert.deepEqual(
      this.receiver.transfers.map((entry) => entry.status),
      ["completed", "transferring", "rejected"]
    );
    this.receiver.dismiss(id);
    assert.false(this.receiver.transfers.some((entry) => entry.hasFile));
  });

  test("a failed completion acknowledgement cannot become completed or retain a File", async function (assert) {
    const id = await this.offer("");
    this.b.remote = null;
    await this.receiver.accept(id);
    this.b.send = () => {
      throw new Error("closed");
    };
    this.message(this.a, "accept", id);
    await waitUntil(() => this.receiver.transfers[0].status === "failed");
    assert.false(this.receiver.transfers[0].hasFile);
    assert.notStrictEqual(this.sender.transfers[0].status, "completed");
  });

  test("oversized and malformed controls close the channel without retaining entries", async function (assert) {
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

  test("receive overflow and oversized binary frames fail without retaining bytes", async function (assert) {
    for (const length of [38, CHUNK_SIZE + 37]) {
      const channel = new Channel();
      const id = crypto.randomUUID();
      this.receiver.attach(1, 9, channel);
      this.message(channel, "offer", id, { name: "x", size: 1 });
      await this.receiver.accept(id);
      const frame = new Uint8Array(length);
      frame.set(new TextEncoder().encode(id));
      channel.onmessage({ data: frame.buffer });
      assert.strictEqual(this.receiver.transfers.at(-1).status, "failed");
      assert.false(this.receiver.transfers.at(-1).hasFile);
      assert.strictEqual(channel.readyState, "closed");
    }
  });

  test("stale transfer frames cannot contaminate a later accepted transfer", async function (assert) {
    const oldId = crypto.randomUUID();
    this.message(this.b, "offer", oldId, { name: "old", size: 1 });
    await this.receiver.accept(oldId);
    this.receiver.cancel(oldId);
    const id = crypto.randomUUID();
    this.message(this.b, "offer", id, { name: "new", size: 0 });
    await this.receiver.accept(id);
    const frame = new Uint8Array(37);
    frame.set(new TextEncoder().encode(oldId));
    this.b.onmessage({ data: frame.buffer });
    this.message(this.b, "complete", id);
    await waitUntil(() => this.receiver.transfers[1].status === "completed");
    assert.strictEqual(this.receiver.transfers[1].status, "completed");
    assert.strictEqual((await this.receiver.getReceivedFile(id)).size, 0);
    this.receiver.dismiss(id);
    assert.false(this.receiver.transfers.some((entry) => entry.hasFile));
  });

  test("stale cancelled frames leave a new pending offer intact, but matching preaccept bytes close it", async function (assert) {
    const oldId = crypto.randomUUID();
    this.message(this.b, "offer", oldId, { name: "old", size: 1 });
    await this.receiver.accept(oldId);
    this.receiver.cancel(oldId);
    const id = crypto.randomUUID();
    this.message(this.b, "offer", id, { name: "new", size: 1 });
    const frame = new Uint8Array(37);
    frame.set(new TextEncoder().encode(oldId));
    this.b.onmessage({ data: frame.buffer });
    assert.strictEqual(this.receiver.transfers[1].status, "pending");
    assert.strictEqual(this.receiver.transfers[1].progress, 0);
    assert.false(this.receiver.transfers[1].hasFile);
    assert.strictEqual(
      this.b.readyState,
      "open",
      "stale bytes do not close the channel"
    );
    frame.set(new TextEncoder().encode(id));
    this.b.onmessage({ data: frame.buffer });
    assert.strictEqual(this.receiver.transfers[1].status, "failed");
    assert.false(this.receiver.transfers[1].hasFile);
    assert.strictEqual(
      this.b.readyState,
      "closed",
      "matching bytes still require acceptance"
    );
  });

  test("retained history is bounded even when a peer floods offers", async function (assert) {
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
  test("accept waits for disk initialization and cancellation discards late sink", async function (assert) {
    const opened = deferred();
    this.receiver.destroy();
    this.receiver = new FileTransferManager({
      isEligible: () => true,
      openReceiveSink: () => opened.promise,
    });
    this.receiver.attach(1, 1, this.b);
    const id = await this.offer();
    const acceptance = this.receiver.accept(id);
    assert.strictEqual(this.receiver.transfers[0].status, "initializing");
    assert.false(this.b.sent.some((d) => JSON.parse(d).type === "accept"));
    this.receiver.cancel(id);
    const sink = new TestSink();
    opened.resolve(sink);
    await acceptance;
    assert.true(sink.discarded);
    assert.strictEqual(this.receiver.transfers[0].status, "cancelled");
  });

  test("unavailable storage fails closed before accept", async function (assert) {
    this.receiver.destroy();
    this.receiver = new FileTransferManager({
      isEligible: () => true,
      openReceiveSink: async () => {
        throw new Error("OPFS missing");
      },
    });
    this.receiver.attach(1, 1, this.b);
    const id = await this.offer();
    await this.receiver.accept(id);
    assert.strictEqual(this.receiver.transfers[0].error, "storage_unavailable");
    assert.false(this.b.sent.some((d) => JSON.parse(d).type === "accept"));
    assert.false(this.receiver.transfers[0].hasFile);
  });

  test("slow disk bounds sender window and flush gates completion", async function (assert) {
    const write = deferred();
    const finish = deferred();
    const id = await this.offer("x".repeat(RECEIVE_WINDOW + 1));
    await this.receiver.accept(id);
    this.sinks[0].write = (chunk) => {
      this.sinks[0].chunks.push(chunk);
      return write.promise;
    };
    this.sinks[0].finish = () => finish.promise;
    await waitUntil(() => this.a.sent.some((d) => d instanceof ArrayBuffer));
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.strictEqual(
      this.a.sent.filter((d) => d instanceof ArrayBuffer).length,
      RECEIVE_WINDOW / CHUNK_SIZE
    );
    assert.false(
      this.b.sent.some(
        (data) => typeof data === "string" && JSON.parse(data).type === "ack"
      ),
      "no ACK until disk persistence"
    );
    write.resolve();
    await waitUntil(
      () =>
        this.a.sent.filter((d) => d instanceof ArrayBuffer).length ===
        RECEIVE_WINDOW / CHUNK_SIZE + 1
    );
    await waitUntil(() =>
      this.a.sent.some(
        (d) => typeof d === "string" && JSON.parse(d).type === "complete"
      )
    );
    assert.strictEqual(this.sender.transfers[0].status, "transferring");
    finish.resolve(new File(["x".repeat(RECEIVE_WINDOW + 1)], "received"));
    await waitUntil(() => this.sender.transfers[0].status === "completed");
    assert.true((await this.receiver.getReceivedFile(id)) instanceof File);
  });

  test("abusive peer exceeds bounded disk window and gets disconnected", async function (assert) {
    const id = crypto.randomUUID();
    this.message(this.b, "offer", id, {
      name: "x",
      size: RECEIVE_WINDOW + CHUNK_SIZE,
    });
    await this.receiver.accept(id);
    const write = deferred();
    this.sinks[0].write = () => write.promise;
    const frame = new Uint8Array(36 + CHUNK_SIZE);
    frame.set(new TextEncoder().encode(id));
    for (let i = 0; i <= RECEIVE_WINDOW / CHUNK_SIZE; i++) {
      this.b.onmessage({ data: frame.buffer });
    }
    assert.strictEqual(this.receiver.transfers[0].status, "failed");
    assert.strictEqual(this.b.readyState, "closed");
    write.resolve();
    await Promise.resolve();
    assert.false(this.receiver.transfers[0].hasFile);
  });

  test("write failures clean storage and late finalize cannot restore dismissed entry", async function (assert) {
    let id = await this.offer();
    await this.receiver.accept(id);
    const sink = this.sinks[0];
    sink.write = async () => {
      throw new Error("quota");
    };
    await waitUntil(() => this.receiver.transfers[0].status === "failed");
    assert.strictEqual(this.receiver.transfers[0].error, "storage_failed");
    await waitUntil(() => sink.discarded);
    this.sender.dismiss(id);
    this.receiver.dismiss(id);
    const flush = deferred();
    id = await this.offer("");
    await this.receiver.accept(id);
    this.sinks[1].finish = () => flush.promise;
    await waitUntil(() =>
      this.a.sent.some(
        (d) =>
          typeof d === "string" &&
          JSON.parse(d).id === id &&
          JSON.parse(d).type === "complete"
      )
    );
    this.receiver.dismiss(id);
    flush.resolve(new File([], "received"));
    await Promise.resolve();
    await Promise.resolve();
    assert.deepEqual(this.receiver.transfers, []);
    assert.true(this.sinks[1].discarded);
  });

  test("completed disk files survive disconnect but dismiss, leave and destroy discard them", async function (assert) {
    const id = await this.offer();
    await this.receiver.accept(id);
    await waitUntil(() => this.receiver.transfers[0].status === "completed");
    const sink = this.sinks[0];
    this.receiver.disconnect(1, 1);
    assert.false(sink.discarded);
    assert.true((await this.receiver.getReceivedFile(id)) instanceof File);
    this.receiver.dismiss(id);
    await waitUntil(() => sink.discarded);
  });

  test("send and receive permissions are independent", async function (assert) {
    this.receiver.destroy();
    this.receiver = new FileTransferManager({
      isEligible: () => true,
      isSendAllowed: () => false,
      isReceiveAllowed: () => true,
      openReceiveSink: this.openSink,
    });
    this.b = new Channel();
    this.a.remote = this.b;
    this.b.remote = this.a;
    this.receiver.attach(1, 1, this.b);
    assert.false(this.receiver.canSend(1, 1));
    const id = await this.offer();
    await this.receiver.accept(id);
    await waitUntil(() => this.receiver.transfers[0].status === "completed");
    assert.strictEqual(
      await (
        await this.receiver.getReceivedFile(this.receiver.transfers[0].id)
      ).text(),
      "hello"
    );
  });
  test("receive denial rejects offers without allocating a sink", async function (assert) {
    this.receiver.destroy();
    let allocations = 0;
    this.receiver = new FileTransferManager({
      isEligible: () => true,
      isSendAllowed: () => true,
      isReceiveAllowed: () => false,
      openReceiveSink: async () => {
        allocations++;
        return new TestSink();
      },
    });
    this.b = new Channel();
    this.a.remote = this.b;
    this.b.remote = this.a;
    this.receiver.attach(1, 1, this.b);
    assert.true(this.receiver.canSend(1, 1));
    const id = await this.offer();
    await this.receiver.accept(id);
    assert.strictEqual(allocations, 0);
    assert.deepEqual(this.receiver.transfers, []);
    await waitUntil(() => this.sender.transfers[0].status === "rejected");
  });
  test("leave and destroy clean completed disk sinks without explicit Save", async function (assert) {
    for (const action of ["leave", "destroy"]) {
      const sink = new TestSink();
      const manager = new FileTransferManager({
        isEligible: () => true,
        openReceiveSink: async () => sink,
      });
      const channel = new Channel();
      manager.attach(1, 2, channel);
      const id = crypto.randomUUID();
      this.message(channel, "offer", id, { name: "empty", size: 0 });
      await manager.accept(id);
      this.message(channel, "complete", id);
      await waitUntil(() => manager.transfers[0].status === "completed");
      assert.true(manager.transfers[0].hasFile);
      assert.false(
        "blob" in manager.transfers[0],
        "no File retained on public entry"
      );
      manager[action](1);
      await waitUntil(() => sink.discarded);
      assert.deepEqual(manager.transfers, []);
      await assert.rejects(manager.getReceivedFile(id));
      manager.destroy();
    }
  });
  test("retiring disk files retain budget until delayed deletion resolves", async function (assert) {
    const deletion = deferred();
    for (let userId = 10; userId < 13; userId++) {
      const channel = new Channel();
      this.receiver.attach(1, userId, channel);
      const id = crypto.randomUUID();
      this.message(channel, "offer", id, {
        name: "large",
        size: DEFAULT_MAX_FILE_SIZE,
      });
      await this.receiver.accept(id);
      if (userId < 12) {
        this.sinks.at(-1).discard = () => deletion.promise;
        this.receiver.dismiss(id);
      }
    }
    assert.strictEqual(
      this.receiver.transfers.at(-1).status,
      "rejected",
      "two retiring files still reserve 200 MiB"
    );
    deletion.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    const channel = new Channel();
    this.receiver.attach(1, 20, channel);
    const id = crypto.randomUUID();
    this.message(channel, "offer", id, {
      name: "large",
      size: DEFAULT_MAX_FILE_SIZE,
    });
    await this.receiver.accept(id);
    assert.strictEqual(
      this.receiver.transfers.at(-1).status,
      "transferring",
      "confirmed deletion releases the reservation"
    );
  });

  module("configured limits", function (limitHooks) {
    limitHooks.beforeEach(function () {
      this.sender.destroy();
      this.receiver.destroy();
      this.maxSize = MEBIBYTE;
      this.sender = new FileTransferManager({
        isEligible: () => this.eligible,
        getMaxFileSize: () => this.maxSize,
      });
      this.receiver = new FileTransferManager({
        isEligible: () => this.eligible,
        getMaxFileSize: () => this.maxSize,
        openReceiveSink: this.openSink,
      });
      this.a = new Channel();
      this.b = new Channel();
      this.a.remote = this.b;
      this.b.remote = this.a;
      this.sender.attach(1, 2, this.a);
      this.receiver.attach(1, 1, this.b);
      this.sizedFile = (size) => {
        const file = new File([], "metadata.bin");
        Object.defineProperty(file, "size", { value: size });
        return file;
      };
    });

    test("sender allows the exact limit and rejects one byte more", function (assert) {
      assert.throws(
        () => this.sender.send(1, 2, this.sizedFile(this.maxSize + 1)),
        "oversized outgoing metadata is rejected"
      );
      const id = this.sender.send(1, 2, this.sizedFile(this.maxSize));
      assert.strictEqual(
        this.sender.transfers[0].id,
        id,
        "exact limit is allowed"
      );
    });

    test("incoming offers allow the exact limit and reject one byte more", function (assert) {
      const oversizedId = crypto.randomUUID();
      this.message(this.b, "offer", oversizedId, {
        name: "large.bin",
        size: this.maxSize + 1,
      });
      assert.deepEqual(
        this.receiver.transfers,
        [],
        "oversized offer is not retained"
      );
      assert.strictEqual(
        JSON.parse(this.b.sent.at(-1)).type,
        "reject",
        "peer is notified"
      );
      this.message(this.b, "offer", crypto.randomUUID(), {
        name: "exact.bin",
        size: this.maxSize,
      });
      assert.strictEqual(
        this.receiver.transfers[0].status,
        "pending",
        "exact limit is allowed"
      );
    });

    test("256 MiB metadata is allowed on both ends without allocating file contents", async function (assert) {
      this.maxSize = 256 * MEBIBYTE;
      const id = this.sender.send(1, 2, this.sizedFile(this.maxSize));
      await Promise.resolve();
      assert.strictEqual(
        this.receiver.transfers[0].id,
        id,
        "offer above the old limit is received"
      );
      assert.strictEqual(
        this.receiver.transfers[0].status,
        "pending",
        "no bytes are requested"
      );
      assert.strictEqual(
        this.sinks.length,
        0,
        "no disk allocation before consent"
      );
    });

    test("lowering the limit invalidates a pending offer before opening storage", async function (assert) {
      const id = crypto.randomUUID();
      this.message(this.b, "offer", id, {
        name: "pending.bin",
        size: this.maxSize,
      });
      this.maxSize /= 2;
      await this.receiver.accept(id);
      assert.strictEqual(
        this.receiver.transfers[0].status,
        "rejected",
        "pending metadata is rechecked"
      );
      assert.strictEqual(this.sinks.length, 0, "rejection never opens a sink");
    });

    test("lowering the limit while storage opens cancels and discards the sink", async function (assert) {
      const opening = deferred();
      const sink = new TestSink();
      this.receiver.destroy();
      this.receiver = new FileTransferManager({
        isEligible: () => this.eligible,
        getMaxFileSize: () => this.maxSize,
        openReceiveSink: () => opening.promise,
      });
      const channel = new Channel();
      this.receiver.attach(1, 1, channel);
      const id = crypto.randomUUID();
      this.message(channel, "offer", id, {
        name: "pending.bin",
        size: this.maxSize,
      });
      const accepting = this.receiver.accept(id);
      this.maxSize /= 2;
      opening.resolve(sink);
      await accepting;
      await Promise.resolve();
      assert.strictEqual(
        this.receiver.transfers[0].status,
        "cancelled",
        "initializing transfer is cancelled"
      );
      assert.true(sink.discarded, "allocated sink is deleted");
      assert.false(
        channel.sent.some((data) => JSON.parse(data).type === "accept"),
        "peer never gets acceptance"
      );
    });

    test("raising the limit permits 512 MiB of reservations but blocks a third 256 MiB file", async function (assert) {
      this.maxSize = 256 * MEBIBYTE;
      for (let userId = 10; userId < 13; userId++) {
        const channel = new Channel();
        this.receiver.attach(1, userId, channel);
        const id = crypto.randomUUID();
        this.message(channel, "offer", id, {
          name: "large.bin",
          size: this.maxSize,
        });
        await this.receiver.accept(id);
      }
      assert.deepEqual(
        this.receiver.transfers.map((entry) => entry.status),
        ["transferring", "transferring", "rejected"],
        "disk reservations scale with the current configured maximum"
      );
      assert.strictEqual(
        this.sinks.length,
        2,
        "only permitted reservations allocate storage"
      );
    });

    test("invalid byte callbacks fail closed, including empty files", function (assert) {
      for (const invalid of [
        NaN,
        Infinity,
        -1,
        0,
        1.5,
        Number.MAX_SAFE_INTEGER,
        102400 * MEBIBYTE + 1,
      ]) {
        this.maxSize = invalid;
        assert.throws(
          () => this.sender.send(1, 2, this.sizedFile(0)),
          `rejects ${invalid}`
        );
        this.message(this.b, "offer", crypto.randomUUID(), {
          name: "empty.bin",
          size: 0,
        });
      }
      assert.deepEqual(
        this.receiver.transfers,
        [],
        "invalid limits never allow incoming files"
      );
    });
  });
});
