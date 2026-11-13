import { module, test } from "qunit";
import openReceiveSink, {
  STALE_AFTER_MS,
  STORAGE_DIRECTORY,
} from "discourse/plugins/live/discourse/lib/live/file-receive-sink";

function deferred() {
  let resolve;
  const promise = new Promise((yes) => (resolve = yes));
  return { promise, resolve };
}

// Small deterministic OPFS/Web Locks doubles; never touch browser disk in units.
class Locks {
  held = new Set();

  async request(name, options, callback) {
    if (this.held.has(name)) {
      if (options.ifAvailable) {
        return callback(null);
      }
      throw new Error("Unexpected contested lease");
    }
    this.held.add(name);
    try {
      return await callback({ name });
    } finally {
      this.held.delete(name);
    }
  }
}

class Directory {
  kind = "directory";
  children = new Map();
  removed = [];
  failCreate = false;
  failWrite = false;
  failClose = false;
  failAbort = false;
  writeGate = null;
  closeGate = null;
  aborted = false;
  closed = false;
  writes = [];

  async getDirectoryHandle(name) {
    if (!this.children.has(name)) {
      this.children.set(name, new Directory());
    }
    return this.children.get(name);
  }

  async getFileHandle(name) {
    const owner = this;
    return {
      async createWritable() {
        if (owner.failCreate) {
          throw new Error("create failed");
        }
        return {
          async write(chunk) {
            await owner.writeGate;
            if (owner.failWrite) {
              throw new Error("quota");
            }
            owner.writes.push(chunk);
          },
          async close() {
            await owner.closeGate;
            if (owner.failClose) {
              throw new Error("close failed");
            }
            owner.closed = true;
          },
          async abort() {
            owner.aborted = true;
            if (owner.failAbort) {
              throw new Error("abort failed");
            }
          },
        };
      },
      async getFile() {
        return new File(owner.writes, name);
      },
    };
  }

  async removeEntry(name) {
    this.removed.push(name);
    this.children.delete(name);
  }

  async *entries() {
    yield* this.children.entries();
  }
}

module("Live | Unit | Lib | file-receive-sink", function (hooks) {
  hooks.beforeEach(function () {
    this.root = new Directory();
    this.directory = new Directory();
    this.root.children.set(STORAGE_DIRECTORY, this.directory);
    this.locks = new Locks();
    this.now = 1_800_000_000_000;
    this.uuid = "12345678-1234-1234-1234-123456789abc";
    this.namespace = `${this.now}-${this.uuid}`;
    this.session = new Directory();
    this.directory.children.set(this.namespace, this.session);
    this.options = {
      storage: { getDirectory: async () => this.root },
      locks: this.locks,
      now: this.now,
      exportGraceMs: 0,
      randomUUID: () => this.uuid,
    };
  });

  test("requires OPFS and Web Locks, with no memory fallback", async function (assert) {
    await assert.rejects(
      openReceiveSink("x", { ...this.options, storage: {} })
    );
    await assert.rejects(openReceiveSink("x", { ...this.options, locks: {} }));
  });

  test("writes, closes and returns native File while retaining lease until discard", async function (assert) {
    const sink = await openReceiveSink("../../not-a-path", this.options);
    await sink.write(new TextEncoder().encode("hello").buffer);
    const metadata = await sink.finish();
    assert.strictEqual(metadata.size, 5);
    const file = await sink.getFile();
    assert.true(file instanceof File);
    assert.strictEqual(await file.text(), "hello");
    assert.strictEqual(
      file.name,
      this.uuid,
      "never use user names as disk paths"
    );
    assert.true(this.session.closed);
    assert.strictEqual(
      this.locks.held.size,
      1,
      "completed File remains protected"
    );
    await sink.discard();
    await sink.discard();
    assert.deepEqual(this.directory.removed, [this.namespace]);
    assert.strictEqual(this.locks.held.size, 0);
    assert.false(this.session.aborted, "closed stream needs no abort");
  });

  test("initialization failure removes late-created namespace and releases lease", async function (assert) {
    this.session.failCreate = true;
    await assert.rejects(openReceiveSink("x", this.options));
    assert.deepEqual(this.directory.removed, [this.namespace]);
    assert.strictEqual(this.locks.held.size, 0);
  });

  test("write and close errors clean files even when abort fails", async function (assert) {
    for (const failure of ["failWrite", "failClose"]) {
      this.directory.children.set(this.namespace, this.session);
      this.session.failWrite = false;
      this.session.failClose = false;
      this.session[failure] = true;
      this.session.failAbort = true;
      const sink = await openReceiveSink("x", this.options);
      await assert.rejects(
        failure === "failWrite" ? sink.write(new ArrayBuffer(1)) : sink.finish()
      );
      await sink.discard();
      assert.false(this.directory.children.has(this.namespace));
      assert.strictEqual(this.locks.held.size, 0);
    }
  });

  test("discard during pending write waits before abort/removal and prevents further writes", async function (assert) {
    const gate = deferred();
    this.session.writeGate = gate.promise;
    const sink = await openReceiveSink("x", this.options);
    const write = sink.write(new ArrayBuffer(1));
    const cleanup = sink.discard();
    assert.deepEqual(this.directory.removed, []);
    gate.resolve();
    await assert.rejects(write);
    await cleanup;
    assert.true(this.session.aborted);
    assert.deepEqual(this.directory.removed, [this.namespace]);
    await assert.rejects(sink.write(new ArrayBuffer(1)));
    await assert.rejects(sink.finish());
  });

  test("discard during close prevents late File and removes after close", async function (assert) {
    const gate = deferred();
    this.session.closeGate = gate.promise;
    const sink = await openReceiveSink("x", this.options);
    const finish = sink.finish();
    const cleanup = sink.discard();
    assert.deepEqual(this.directory.removed, []);
    gate.resolve();
    await assert.rejects(finish);
    await cleanup;
    assert.true(this.session.closed);
    assert.deepEqual(this.directory.removed, [this.namespace]);
    assert.strictEqual(this.locks.held.size, 0);
  });

  test("orphan sweep deletes old unlocked namespaces only, never active tabs or foreign entries", async function (assert) {
    const old = `${this.now - STALE_AFTER_MS - 1}-${this.uuid}`;
    const active = `${this.now - STALE_AFTER_MS - 2}-${this.uuid}`;
    this.directory.children.set(old, new Directory());
    this.directory.children.set(active, new Directory());
    this.directory.children.set("foreign-directory", new Directory());
    this.locks.held.add(`${STORAGE_DIRECTORY}:${active}`);
    const sink = await openReceiveSink("x", this.options);
    assert.deepEqual(this.directory.removed, [old]);
    assert.true(this.directory.children.has(active));
    assert.true(this.directory.children.has("foreign-directory"));
    assert.true(this.directory.children.has(this.namespace));
    await sink.discard();
  });
  test("explicit Save defers deletion and lease release past download URL lifetime", async function (assert) {
    let now = this.now;
    let callback;
    let cleared = false;
    const sink = await openReceiveSink("x", {
      ...this.options,
      exportGraceMs: 30_000,
      clock: () => now,
      setTimer: (fn, delay) => {
        assert.strictEqual(delay, 30_000);
        callback = fn;
        return 123;
      },
      clearTimer: (timer) => {
        assert.strictEqual(timer, 123);
        cleared = true;
      },
    });
    await sink.finish();
    await sink.getFile();
    now += 10_000;
    await sink.getFile(); // Repeated Save extends the lease.
    const cleanup = sink.discard();
    await Promise.resolve();
    assert.deepEqual(this.directory.removed, []);
    assert.strictEqual(this.locks.held.size, 1);
    await assert.rejects(
      sink.getFile(),
      "discard immediately denies further exports"
    );
    now += 30_000;
    callback();
    await cleanup;
    assert.deepEqual(this.directory.removed, [this.namespace]);
    assert.strictEqual(this.locks.held.size, 0);
    assert.true(cleared);
  });
  test("failed deletion rejects cleanup rather than claiming disk space was freed", async function (assert) {
    const sink = await openReceiveSink("x", this.options);
    this.directory.removeEntry = async () => {
      throw new Error("disk unavailable");
    };
    await assert.rejects(sink.discard());
    assert.strictEqual(
      this.locks.held.size,
      0,
      "orphan sweep can retry after lease release"
    );
  });
});
