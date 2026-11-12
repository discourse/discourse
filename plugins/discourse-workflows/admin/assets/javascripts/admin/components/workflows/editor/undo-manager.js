import loadRete from "discourse/lib/load-rete";

const MAX_HISTORY_SIZE = 25;

class SnapshotAction {
  constructor(before, after, applyFn) {
    this.before = before;
    this.after = after;
    this.applyFn = applyFn;
  }

  undo() {
    this.applyFn(this.before);
  }

  redo() {
    this.applyFn(this.after);
  }
}

export default class UndoManager {
  #history = null;
  #pendingBefore = null;
  #applyFn = null;

  get canUndo() {
    return this.#history?.getHistorySnapshot().length > 0;
  }

  get canRedo() {
    return this.#history?.history.reserved.length > 0;
  }

  get hasPendingCapture() {
    return this.#pendingBefore !== null;
  }

  async initialize(area, applyFn) {
    const { HistoryPlugin } = await loadRete();
    this.#history = new HistoryPlugin({ timing: 200 });
    this.#applyFn = applyFn;
    area.use(this.#history);
  }

  captureBeforeState(snapshot) {
    this.#pendingBefore = structuredClone(snapshot);
  }

  commitAction(afterSnapshot) {
    if (!this.#history || !this.#pendingBefore) {
      return;
    }

    const before = this.#pendingBefore;
    const after = structuredClone(afterSnapshot);
    this.#pendingBefore = null;

    this.#history.add(new SnapshotAction(before, after, this.#applyFn));

    const produced = this.#history.getHistorySnapshot();
    if (produced.length > MAX_HISTORY_SIZE) {
      produced.splice(0, produced.length - MAX_HISTORY_SIZE);
    }
  }

  async undo() {
    if (!this.#history) {
      return;
    }
    await this.#history.undo();
  }

  async redo() {
    if (!this.#history) {
      return;
    }
    await this.#history.redo();
  }

  clear() {
    this.#history?.clear();
  }

  destroy() {
    this.#history = null;
    this.#applyFn = null;
    this.#pendingBefore = null;
  }
}
