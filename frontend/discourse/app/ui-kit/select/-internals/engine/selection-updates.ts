import { isDestroying } from "@ember/destroyable";
import { waitForPromise } from "@ember/test-waiters";
import { makeArray } from "discourse/lib/helpers";
import type {
  SelectUpdateScope,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import type SelectOptionsView from "./select-options.ts";
import type { SelectState } from "./select-sources.ts";
import type SelectionActions from "./selection-actions.ts";

/** Distinguishes one update's writes from external selection intent. */
export type SelectionOrigin = (
  | { record: UpdateRecord; programmatic?: never }
  | { programmatic: true; record?: never }
) & {
  /** Counts for one combined bulk-add announcement. */
  bulk?: {
    /** Items added after filtering and truncation. */
    added: number;
    /** Already-held or repeated items. */
    held: number;
    /** Eligible items excluded by the selection cap. */
    limit: number;
  };
};

/**
 * One update: its scope, the `done` barrier the trigger waits on, and the value keys it still
 * owns. Ending normally keeps an already queued commit valid; revoking does not.
 */
export class UpdateRecord {
  readonly done: Promise<void>;
  readonly scope: SelectUpdateScope;
  keys: Set<string>;
  asynchronous = false;
  ended = false;
  revoked = false;
  #controller = new AbortController();
  #resolve!: () => void;

  constructor(key: string, scope: (record: UpdateRecord) => SelectUpdateScope) {
    this.keys = new Set([key]);
    this.done = new Promise((resolve) => (this.#resolve = resolve));
    this.scope = scope(this);
  }

  get signal(): AbortSignal {
    return this.#controller.signal;
  }

  abort(): void {
    this.#controller.abort();
  }

  end(): void {
    this.ended = true;
    this.#resolve();
  }
}

/** Owns update authority separately from its asynchronous, tracked display state. */
export default class SelectionUpdates {
  #actions: SelectionActions;
  #engine: object;
  #options: SelectOptionsView;
  #state: SelectState;
  #current: UpdateRecord | null = null;

  constructor(opts: {
    engine: object;
    options: SelectOptionsView;
    state: SelectState;
    actions: SelectionActions;
  }) {
    this.#actions = opts.actions;
    this.#engine = opts.engine;
    this.#options = opts.options;
    this.#state = opts.state;
  }

  get done(): Promise<void> | undefined {
    const update = this.#state.update;
    return update && update === this.#current ? update.done : undefined;
  }

  get pending(): boolean {
    return !isDestroying(this.#engine) && this.#state.update !== null;
  }

  handleIntent(origin?: SelectionOrigin): void {
    if (!origin?.record || origin.record !== this.#current) {
      this.supersede();
    }
  }

  /** Runs at the actual emit, including when a transformer defers its callback. */
  prepareEmit(
    origin: SelectionOrigin | undefined,
    value: SelectValue
  ): boolean {
    const record = origin?.record;
    if (!record) {
      return true;
    }
    if (record.revoked) {
      return false;
    }
    record.keys = new Set([
      this.#valueKey(this.#actions.value),
      this.#valueKey(value),
    ]);
    return true;
  }

  supersede(): void {
    const record = this.#current;
    if (record) {
      record.revoked = true;
      this.#end(record);
      record.abort();
    }
  }

  update(
    work: (scope: SelectUpdateScope) => void | Promise<void>
  ): Promise<void> {
    if (isDestroying(this.#engine)) {
      return Promise.resolve();
    }
    this.supersede();
    const record = new UpdateRecord(this.#valueKey(this.#actions.value), (r) =>
      this.#scope(r)
    );
    this.#current = record;

    let result: void | Promise<void>;
    try {
      result = work(record.scope);
      if (!result || typeof result.then !== "function") {
        this.#end(record);
        return Promise.resolve();
      }
    } catch (reason) {
      this.#end(record);
      return Promise.reject(reason);
    }

    if (this.#current === record && !isDestroying(this.#engine)) {
      record.asynchronous = true;
      this.#state.update = record;
      this.#options.onUpdateStart?.(() => this.#isCurrent(record));
    }
    const chain = Promise.resolve(result).then(
      () => this.#end(record),
      (reason: unknown) => {
        this.#end(record);
        throw reason;
      }
    );
    return waitForPromise(chain);
  }

  #end(record: UpdateRecord): void {
    record.end();
    if (this.#current === record) {
      this.#current = null;
      if (record.asynchronous && !isDestroying(this.#engine)) {
        this.#state.update = null;
      }
    }
  }

  #isCurrent(record: UpdateRecord): boolean {
    return (
      this.#current === record &&
      !record.ended &&
      !record.revoked &&
      !isDestroying(this.#engine) &&
      record.keys.has(this.#valueKey(this.#actions.value))
    );
  }

  #scope(record: UpdateRecord): SelectUpdateScope {
    const current = () => this.#isCurrent(record);
    return Object.freeze<SelectUpdateScope>({
      signal: record.signal,
      get current() {
        return current();
      },
      select: (item) =>
        this.#write(record, () => this.#actions.select(item, { record })),
      selectMany: (items) =>
        this.#write(record, () => this.#actions.selectMany(items, { record })),
      deselect: (item) =>
        this.#write(record, () => this.#actions.deselect(item, { record })),
      clear: () => this.#write(record, () => this.#actions.clear({ record })),
    });
  }

  #valueKey(value: SelectValue): string {
    return JSON.stringify(
      makeArray(value).map((id) => this.#options.valueKey(id))
    );
  }

  #write(record: UpdateRecord, write: () => void): void {
    if (!this.#isCurrent(record)) {
      if (this.#current === record) {
        this.supersede();
      }
      return;
    }
    if (!this.#options.locked) {
      write();
    }
  }
}
