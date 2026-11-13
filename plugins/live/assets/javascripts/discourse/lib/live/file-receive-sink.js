// Origin-private temporary files only. Never fall back to whole-file RAM.
export const SAVE_GRACE_MS = 30_000;
export const STORAGE_DIRECTORY = "live-file-transfers";
export const STALE_AFTER_MS = 24 * 60 * 60 * 1000;
const NAMESPACE = /^(\d{13})-[0-9a-f-]{36}$/;

// Keep a Web Lock for the entire retained File lifetime, not just while its
// writable stream is open. Age alone cannot distinguish an orphan from a file
// another tab is still offering for Save.
async function acquireLease(locks, namespace, ifAvailable = false) {
  let release;
  let acquired;
  let failed;
  const held = new Promise((resolve) => (release = resolve));
  const ready = new Promise((resolve, reject) => {
    acquired = resolve;
    failed = reject;
  });
  const request = locks.request(
    `${STORAGE_DIRECTORY}:${namespace}`,
    { mode: "exclusive", ifAvailable },
    async (lock) => {
      if (!lock) {
        acquired(null);
        return;
      }
      acquired(async () => {
        release();
        await request;
      });
      await held;
    }
  );
  request.catch(failed);
  return ready;
}

async function removeOrphans(directory, locks, now) {
  for await (const [name, handle] of directory.entries()) {
    const match = NAMESPACE.exec(name);
    if (
      handle.kind !== "directory" ||
      !match ||
      Number(match[1]) >= now - STALE_AFTER_MS
    ) {
      continue;
    }
    const release = await acquireLease(locks, name, true);
    if (!release) {
      continue;
    }
    try {
      await directory.removeEntry(name, { recursive: true });
    } catch {
      // Best effort: a failed sweep must not prevent a fresh receive.
    } finally {
      await release();
    }
  }
}

export class ReceiveDiskSink {
  #directory;
  #namespace;
  #handle;
  #writable;
  #release;
  #busy = null;
  #closed = false;
  #discarded = false;
  #cleanup;
  #exportedUntil = 0;
  #retention;
  #deleteTimer = null;

  constructor(directory, namespace, handle, writable, release, retention) {
    this.#directory = directory;
    this.#namespace = namespace;
    this.#handle = handle;
    this.#writable = writable;
    this.#release = release;
    this.#retention = retention;
  }

  write(chunk) {
    return this.#operation(() => this.#writable.write(chunk));
  }

  finish() {
    return this.#operation(async () => {
      await this.#writable.close();
      this.#closed = true;
      if (this.#discarded) {
        throw new Error("Disk receive was discarded");
      }
      // Native File snapshot reads lazily from OPFS; do not arrayBuffer() or
      // assemble a new Blob from all chunks here. UI supplies the display name.
      const file = await this.#handle.getFile();
      return { size: file.size };
    });
  }

  async getFile() {
    if (!this.#closed || this.#discarded || this.#busy) {
      throw new Error("Received disk file is unavailable");
    }
    const file = await this.#handle.getFile();
    if (this.#discarded) {
      throw new Error("Received disk file was discarded");
    }
    this.#exportedUntil =
      this.#retention.clock() + this.#retention.exportGraceMs;
    return file;
  }

  discard() {
    this.#discarded = true;
    if (!this.#cleanup) {
      this.#cleanup = this.#remove();
    }
    return this.#cleanup;
  }

  #operation(action) {
    if (this.#discarded || this.#closed || this.#busy) {
      return Promise.reject(new Error("Disk receive sink is not writable"));
    }
    const operation = Promise.resolve()
      .then(action)
      .then((result) => {
        if (this.#discarded) {
          throw new Error("Disk receive was discarded");
        }
        return result;
      })
      .finally(() => {
        this.#busy = null;
      });
    this.#busy = operation;
    // Cleanup waits for the operation to settle, so abort/remove can never
    // race a late close. Also observe the automatic cleanup's rejection.
    operation.catch(() => {
      this.discard().catch(() => {});
    });
    return operation;
  }

  async #remove() {
    try {
      await this.#busy;
    } catch {
      // Failed writes/close still need abort and directory removal.
    }
    if (!this.#closed) {
      try {
        await this.#writable.abort();
      } catch {
        // The stream may already be errored; still attempt removal.
      }
    }
    // Clicking a download link only starts a lazy disk read. Preserve the file
    // and its lease beyond the download helper's URL lifetime after explicit
    // Save, even if the UI is immediately dismissed or the room is left.
    const delay = this.#exportedUntil - this.#retention.clock();
    if (delay > 0) {
      await new Promise((resolve) => {
        this.#deleteTimer = this.#retention.setTimer(resolve, delay);
      });
    }
    try {
      await this.#directory.removeEntry(this.#namespace, { recursive: true });
    } finally {
      // Removal failures propagate: the manager must not claim reclaimed space.
      if (this.#deleteTimer !== null) {
        this.#retention.clearTimer(this.#deleteTimer);
        this.#deleteTimer = null;
      }
      await this.#release();
    }
  }
}

// Dependencies are injectable for unit tests; production uses only real OPFS.
export default async function openReceiveSink(
  _displayName,
  {
    storage = globalThis.navigator?.storage,
    locks = globalThis.navigator?.locks,
    now = Date.now(),
    randomUUID = () => crypto.randomUUID(),
    exportGraceMs = SAVE_GRACE_MS,
    clock = () => Date.now(),
    setTimer = (callback, delay) => setTimeout(callback, delay),
    clearTimer = (timer) => clearTimeout(timer),
  } = {}
) {
  if (!storage?.getDirectory || !locks?.request) {
    throw new Error("Private disk storage and Web Locks are required");
  }
  const root = await storage.getDirectory();
  const directory = await root.getDirectoryHandle(STORAGE_DIRECTORY, {
    create: true,
  });
  try {
    await removeOrphans(directory, locks, now);
  } catch {
    // Enumeration failure is nonfatal; initialization below still fails closed
    // if this origin cannot create a new file and writable stream.
  }
  const namespace = `${now}-${randomUUID()}`;
  const release = await acquireLease(locks, namespace);
  let writable;
  try {
    const session = await directory.getDirectoryHandle(namespace, {
      create: true,
    });
    const handle = await session.getFileHandle(randomUUID(), { create: true });
    writable = await handle.createWritable();
    return new ReceiveDiskSink(
      directory,
      namespace,
      handle,
      writable,
      release,
      {
        exportGraceMs,
        clock,
        setTimer,
        clearTimer,
      }
    );
  } catch (error) {
    try {
      await writable?.abort();
    } catch {
      // Removal must still happen after an abort failure.
    }
    try {
      await directory.removeEntry(namespace, { recursive: true });
    } catch {
      // A failed initialization may have created no directory, or be orphaned.
    } finally {
      await release();
    }
    throw error;
  }
}
