import type {
  SelectControl,
  SelectId,
  SelectRecord,
} from "discourse/ui-kit/select/select-engine";
import {
  isSelectOption,
  recordOf,
  registerItemRecord,
  sameSettings,
  type SelectOptionLike,
  type SelectOptionSettings,
} from "./select-option.ts";

/** The record fields an item derives its presentation from. */
export interface SelectItemFields {
  labelField: string;
  iconField?: string;
  descriptionField?: string;
}

/** Which surface asks for an item. Each keeps its own memo; the record is the same in both. */
export type SelectItemView =
  | { kind: "list"; input: SelectOptionLike }
  | { kind: "held"; input?: SelectOptionLike };

/** What each source knows about a key, as an input: a record or a record with settings. */
export interface SelectItemContributions {
  /** The requesting view's own input: the row's option, or the at-rest input. */
  view?: SelectOptionLike;
  valueRecords?: SelectOptionLike;
  /** The pick that put the key in the held value, while it is held. */
  pick?: SelectOptionLike;
  /** The resolver answer, while its record is the item's record. */
  answer?: SelectOptionLike;
}

/** What the engine provides an {@link ItemDirectory}. */
export interface SelectItemSources {
  fields(): SelectItemFields;
  valueOf(record: SelectRecord): SelectId;
  /** The key-scope record, and whether it is the unresolved fallback. */
  recordFor(
    key: string,
    view: SelectItemView
  ): { record: SelectRecord; unresolved: boolean };
  /** What each source knows about the key, given the record the key stands for. */
  contributions(
    key: string,
    view: SelectItemView,
    record: SelectRecord
  ): SelectItemContributions;
  /**
   * The engine's name for an unresolved record, or `undefined` to keep the record's own label
   * (a fallback a caller named already explains itself).
   */
  unresolvedLabel?(record: SelectRecord): string | undefined;
}

/** The order explicit properties merge in: the first source that sets one wins it. */
const PRECEDENCE = ["view", "valueRecords", "pick", "answer"] as const;

const NO_PROPERTIES: Readonly<SelectOptionSettings> = Object.freeze({});

type SelectItemAction = (control: SelectControl) => void;

/**
 * One option as every surface shows it: one per value key, owned by the engine. Its explicit
 * properties are merged from every source that knows the key; what no source set is derived
 * from the record, and only when read, so building an item never reads presentation.
 */
export class SelectItem {
  /** Whether a value is an item the engine built, as opposed to a look-alike object. */
  static is(value: unknown): value is SelectItem {
    return typeof value === "object" && value !== null && #record in value;
  }

  #key: string | null;
  #record: SelectRecord;
  #unresolved: boolean;
  #properties: Readonly<SelectOptionSettings>;
  #sources: SelectItemSources;

  constructor(init: {
    key: string | null;
    record: SelectRecord;
    unresolved: boolean;
    properties: Readonly<SelectOptionSettings>;
    sources: SelectItemSources;
  }) {
    this.#key = init.key;
    this.#record = init.record;
    this.#unresolved = init.unresolved;
    this.#properties = init.properties;
    this.#sources = init.sources;
    registerItemRecord(this, init.record);
    Object.freeze(this);
  }

  /** The normalized value key, or `null` for a row that stands for no value. */
  get key(): string | null {
    return this.#key;
  }

  /** Read from the record when asked, so a raw value change that keeps the key shows here. */
  get value(): SelectId {
    return this.#sources.valueOf(this.#record);
  }

  /** The record every surface and data edge shares for this key. */
  get record(): SelectRecord {
    return this.#record;
  }

  /** Whether the record is the engine's fallback for a value it could not resolve. */
  get unresolved(): boolean {
    return this.#unresolved;
  }

  /** The explicit properties the sources set, merged by precedence. */
  get properties(): Readonly<SelectOptionSettings> {
    return this.#properties;
  }

  /** An explicit label wins, `""` included; otherwise it is derived. */
  get label(): string {
    const explicit = this.#properties.label;
    if (explicit != null) {
      return explicit;
    }
    if (this.#unresolved) {
      const named = this.#sources.unresolvedLabel?.(this.#record);
      if (named != null) {
        return named;
      }
    }
    return String(this.#record[this.#sources.fields().labelField] ?? "");
  }

  /** An explicit icon wins, and `""` means none; otherwise it is derived. */
  get icon(): string | undefined {
    const explicit = this.#properties.icon;
    if (explicit != null) {
      return explicit || undefined;
    }
    return this.#unresolved
      ? undefined
      : this.#derived(this.#sources.fields().iconField);
  }

  /** An explicit description wins, and `""` means none; otherwise it is derived. */
  get description(): string | undefined {
    const explicit = this.#properties.description;
    if (explicit != null) {
      return explicit || undefined;
    }
    return this.#unresolved
      ? undefined
      : this.#derived(this.#sources.fields().descriptionField);
  }

  get disabled(): boolean {
    return !!this.#properties.disabled;
  }

  /** The winning `onSelect`, already bound to the record it was written for. */
  get action(): SelectItemAction | undefined {
    return (this.#properties.onSelect as SelectItemAction | null) ?? undefined;
  }

  #derived(field: string | undefined): string | undefined {
    if (!field) {
      return undefined;
    }
    const value = this.#record[field];
    return typeof value === "string" && value !== "" ? value : undefined;
  }
}

/** Whether a value is an item the engine built. */
export function isSelectItem(value: unknown): value is SelectItem {
  return SelectItem.is(value);
}

/**
 * Builds and memoises the items for one engine. Every lookup re-reads the record and each
 * source's contribution, and returns the memoised item only while both are unchanged, so an
 * item's identity changes exactly when what it shows can.
 */
export class ItemDirectory {
  #sources: SelectItemSources;
  #memos = {
    list: new Map<string, SelectItem>(),
    held: new Map<string, SelectItem>(),
  };
  #rows = new WeakMap<object, SelectItem>();

  constructor(sources: SelectItemSources) {
    this.#sources = sources;
  }

  /**
   * The item for a value key, as a view sees it.
   *
   * @param key - A normalized key.
   * @param view - The surface asking, which keeps its own memo.
   */
  itemFor(key: string, view: SelectItemView): SelectItem {
    const item = this.peek(key, view);
    const memo = this.#memos[view.kind];
    const cached = memo.get(key);
    if (
      cached &&
      cached.record === item.record &&
      cached.unresolved === item.unresolved &&
      sameSettings(cached.properties, item.properties)
    ) {
      return cached;
    }
    memo.set(key, item);
    return item;
  }

  /**
   * The item a view would show for a key, built afresh and never memoised, for reads such as
   * matching that must not keep items alive.
   *
   * @param key - A normalized key.
   * @param view - The surface asking.
   */
  peek(key: string, view: SelectItemView): SelectItem {
    const { record, unresolved } = this.#sources.recordFor(key, view);
    return new SelectItem({
      key,
      record,
      unresolved,
      properties: mergeContributions(
        this.#sources.contributions(key, view, record)
      ),
      sources: this.#sources,
    });
  }

  /**
   * The item for a row that stands for no value key: only its own input contributes.
   *
   * @param input - The row's record or option.
   */
  rowItem(input: SelectOptionLike): SelectItem {
    let item = this.#rows.get(input);
    if (!item) {
      const record = recordOf(input) as SelectRecord;
      item = new SelectItem({
        key: null,
        record,
        unresolved: false,
        properties: isSelectOption(input) ? input.settings : NO_PROPERTIES,
        sources: this.#sources,
      });
      this.#rows.set(input, item);
    }
    return item;
  }

  /**
   * Drops the list memo's entries for keys outside `keep`.
   *
   * @param keep - The keys whose list items stay memoised.
   */
  pruneList(keep: ReadonlySet<string>): void {
    prune(this.#memos.list, keep);
  }

  /**
   * Drops the held memo's entries for keys outside `keep`.
   *
   * @param keep - The keys whose held items stay memoised.
   */
  pruneHeld(keep: ReadonlySet<string>): void {
    prune(this.#memos.held, keep);
  }
}

function prune(memo: Map<string, SelectItem>, keep: ReadonlySet<string>) {
  for (const key of [...memo.keys()]) {
    if (!keep.has(key)) {
      memo.delete(key);
    }
  }
}

/** Each property from the highest source that sets it; a source that is silent erases nothing. */
function mergeContributions(
  contributions: SelectItemContributions
): Readonly<SelectOptionSettings> {
  let merged: Record<string, unknown> | undefined;
  for (const tier of PRECEDENCE) {
    const input = contributions[tier];
    if (!input || !isSelectOption(input)) {
      continue;
    }
    for (const [name, value] of Object.entries(input.settings)) {
      merged ??= {};
      if (!Object.hasOwn(merged, name)) {
        merged[name] = value;
      }
    }
  }
  return merged ? Object.freeze(merged) : NO_PROPERTIES;
}
