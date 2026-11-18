import type {
  SelectControl,
  SelectId,
  SelectRecord,
} from "discourse/ui-kit/select/select-engine";
import {
  isSelectOption,
  recordOf,
  registerResolvedRecord,
  sameSettings,
  type SelectOptionLike,
  type SelectOptionSettings,
} from "./select-option.ts";

/** The record fields a resolved option derives its presentation from. */
export interface ResolvedOptionFields {
  labelField: string;
  iconField?: string;
  descriptionField?: string;
}

/** Which surface asks for a resolved option. Each keeps its own memo; the record is the same in both. */
export type ResolvedOptionView =
  | { kind: "list"; input: SelectOptionLike }
  | { kind: "held"; input?: SelectOptionLike };

/** What each source knows about a key, as an input: a record or a record with settings. */
export interface ResolvedOptionContributions {
  /** The requesting view's own input: the row's option, or the at-rest input. */
  view?: SelectOptionLike;
  valueRecords?: SelectOptionLike;
  /** The pick that put the key in the held value, while it is held. */
  pick?: SelectOptionLike;
  /** The resolver answer, while its record is the resolved option's record. */
  answer?: SelectOptionLike;
}

/** What the engine provides an {@link ResolvedOptions}. */
export interface ResolvedOptionSources {
  fields(): ResolvedOptionFields;
  valueOf(record: SelectRecord): SelectId;
  /** The key-scope record, and whether it is the unresolved fallback. */
  recordFor(
    key: string,
    view: ResolvedOptionView
  ): { record: SelectRecord; unresolved: boolean };
  /** What each source knows about the key, given the record the key stands for. */
  contributions(
    key: string,
    view: ResolvedOptionView,
    record: SelectRecord
  ): ResolvedOptionContributions;
  /**
   * The engine's name for an unresolved record, or `undefined` to keep the record's own label
   * (a fallback a caller named already explains itself).
   */
  unresolvedLabel?(record: SelectRecord): string | undefined;
}

/** The order explicit properties merge in: the first source that sets one wins it. */
const PRECEDENCE = ["view", "valueRecords", "pick", "answer"] as const;

const NO_PROPERTIES: Readonly<SelectOptionSettings> = Object.freeze({});

type ResolvedOptionAction = (control: SelectControl) => void;

/**
 * One option as every surface shows it: one per value key, owned by the engine. Its explicit
 * properties are merged from every source that knows the key; what no source set is derived
 * from the record, and only when read, so building a resolved option never reads presentation.
 */
export class SelectResolvedOption {
  /** Whether a value is a resolved option the engine built, as opposed to a look-alike object. */
  static is(value: unknown): value is SelectResolvedOption {
    return typeof value === "object" && value !== null && #record in value;
  }

  #key: string | null;
  #record: SelectRecord;
  #unresolved: boolean;
  #create: boolean;
  #properties: Readonly<SelectOptionSettings>;
  #sources: ResolvedOptionSources;

  constructor(init: {
    key: string | null;
    record: SelectRecord;
    unresolved: boolean;
    create?: boolean;
    properties: Readonly<SelectOptionSettings>;
    sources: ResolvedOptionSources;
  }) {
    this.#key = init.key;
    this.#record = init.record;
    this.#unresolved = init.unresolved;
    this.#create = !!init.create;
    this.#properties = init.properties;
    this.#sources = init.sources;
    registerResolvedRecord(this, init.record);
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

  /** Whether this is the row that creates a value from the query. */
  get create(): boolean {
    return this.#create;
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
  get action(): ResolvedOptionAction | undefined {
    return (
      (this.#properties.onSelect as ResolvedOptionAction | null) ?? undefined
    );
  }

  #derived(field: string | undefined): string | undefined {
    if (!field) {
      return undefined;
    }
    const value = this.#record[field];
    return typeof value === "string" && value !== "" ? value : undefined;
  }
}

/** Whether a value is a resolved option the engine built. */
export function isResolvedOption(
  value: unknown
): value is SelectResolvedOption {
  return SelectResolvedOption.is(value);
}

/**
 * Builds and memoises the resolved options for one engine. Every lookup re-reads the record and each
 * source's contribution, and returns the memoised resolved option only while both are unchanged, so a
 * resolved option's identity changes exactly when what it shows can.
 */
export class ResolvedOptions {
  #sources: ResolvedOptionSources;
  #memos = {
    list: new Map<string, SelectResolvedOption>(),
    held: new Map<string, SelectResolvedOption>(),
  };
  #rows = new WeakMap<object, SelectResolvedOption>();

  /** The input each listed key was last built from, kept as long as its listed resolved option. */
  #listInputs = new Map<string, SelectOptionLike>();

  constructor(sources: ResolvedOptionSources) {
    this.#sources = sources;
  }

  /**
   * The resolved option for a value key, as a view sees it.
   *
   * @param key - A normalized key.
   * @param view - The surface asking, which keeps its own memo.
   */
  resolvedOptionFor(
    key: string,
    view: ResolvedOptionView
  ): SelectResolvedOption {
    const resolved = this.peek(key, view);
    if (view.kind === "list") {
      this.#listInputs.set(key, view.input);
    }
    const memo = this.#memos[view.kind];
    const cached = memo.get(key);
    if (
      cached &&
      cached.record === resolved.record &&
      cached.unresolved === resolved.unresolved &&
      sameSettings(cached.properties, resolved.properties)
    ) {
      return cached;
    }
    memo.set(key, resolved);
    return resolved;
  }

  /**
   * The resolved option a view would show for a key, built afresh and never memoised, for reads such as
   * matching that must not keep resolved options alive.
   *
   * @param key - A normalized key.
   * @param view - The surface asking.
   */
  peek(key: string, view: ResolvedOptionView): SelectResolvedOption {
    const { record, unresolved } = this.#sources.recordFor(key, view);
    return new SelectResolvedOption({
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
   * The resolved option for a row that stands for no value key: only its own input contributes.
   *
   * @param input - The row's record or option.
   */
  rowOption(input: SelectOptionLike): SelectResolvedOption {
    let resolved = this.#rows.get(input);
    if (!resolved) {
      const record = recordOf(input) as SelectRecord;
      resolved = new SelectResolvedOption({
        key: null,
        record,
        unresolved: false,
        create: isSelectOption(input) && input.create,
        properties: isSelectOption(input) ? input.settings : NO_PROPERTIES,
        sources: this.#sources,
      });
      this.#rows.set(input, resolved);
    }
    return resolved;
  }

  /**
   * Drops the list memo's entries for keys outside `keep`, and the row inputs of keys the build
   * did not show.
   *
   * @param keep - The keys whose listed resolved options stay memoised.
   * @param shown - The keys the build showed; `keep` when every kept key was shown.
   */
  pruneList(
    keep: ReadonlySet<string>,
    shown: ReadonlySet<string> = keep
  ): void {
    prune(this.#memos.list, keep);
    for (const key of [...this.#listInputs.keys()]) {
      if (!shown.has(key)) {
        this.#listInputs.delete(key);
      }
    }
  }

  /**
   * The input the list last built a key's row from, while the key is still listed.
   *
   * @param key - A normalized key.
   */
  listInput(key: string): SelectOptionLike | undefined {
    return this.#listInputs.get(key);
  }

  /** Forgets every listed key's input, once no list is shown. */
  forgetListInputs(): void {
    this.#listInputs.clear();
  }

  /**
   * Drops the held memo's entries for keys outside `keep`.
   *
   * @param keep - The keys whose held resolved options stay memoised.
   */
  pruneHeld(keep: ReadonlySet<string>): void {
    prune(this.#memos.held, keep);
  }
}

function prune(
  memo: Map<string, SelectResolvedOption>,
  keep: ReadonlySet<string>
) {
  for (const key of [...memo.keys()]) {
    if (!keep.has(key)) {
      memo.delete(key);
    }
  }
}

/** Each property from the highest source that sets it; a source that is silent erases nothing. */
export function mergeContributions(
  contributions: ResolvedOptionContributions
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
