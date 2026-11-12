import { DEBUG } from "@glimmer/env";
import { createCache, getValue } from "@glimmer/tracking/primitives/cache";
import { assert, warn } from "@ember/debug";
import type {
  SelectConfig,
  SelectPresentationArgs,
} from "discourse/ui-kit/select/-internals/engine/customizations";
import {
  isSelectOption,
  type SelectOption,
  selectOption,
  type SelectOptionLike,
} from "discourse/ui-kit/select/-internals/engine/select-option";
import {
  renderSelectText,
  type SelectTexts,
} from "discourse/ui-kit/select/-internals/engine/select-texts";
import type {
  SelectEngineInit,
  SelectId,
  SelectLegacyContext,
  SelectLoadRequest,
  SelectLoadResult,
  SelectRecord,
  SelectValue,
  SelectValueRecordsBuilder,
} from "discourse/ui-kit/select/select-engine";

/** The default `kindContext` and `instanceContext` data when none was provided. */
const EMPTY_CONTEXT: object = Object.freeze({});

/**
 * The engine's live view over its constructor options. Each reactive input is exposed as a
 * getter that reads its thunk on every access (so a runtime change to the wired `@arg`
 * propagates) and falls back to the static option, then the default. Also hosts the pure
 * field-driven helpers (`valueKey`, `recordValue`, `recordLabel`, `dedupeValues`) so every
 * collaborator applies `valueField`/`labelField` identically.
 */
export default class SelectArgsView {
  #hideSelected?: boolean;
  #readHideSelected?: SelectEngineInit["getHideSelected"];
  #readMultiple?: SelectEngineInit["getMultiple"];
  #readLocked?: SelectEngineInit["getLocked"];
  #multiple?: SelectEngineInit["multiple"];
  #kind?: string;
  #identifier?: string;
  #readKindContext?: SelectEngineInit["getKindContext"];
  #readInstanceContext?: SelectEngineInit["getInstanceContext"];
  #readMinChars?: SelectEngineInit["getMinChars"];
  #minChars?: SelectEngineInit["minChars"];
  #readMaxLoaded?: SelectEngineInit["getMaxLoaded"];
  #maxLoaded?: SelectEngineInit["maxLoaded"];
  #readMaximum?: SelectEngineInit["getMaximum"];
  #maximum?: SelectEngineInit["maximum"];
  #hasWarnedMaximum = false;
  #readMinimum?: SelectEngineInit["getMinimum"];
  #minimum?: SelectEngineInit["minimum"];
  #readLockedValues?: SelectEngineInit["getLockedValues"];
  #lockedValues?: SelectEngineInit["lockedValues"];

  /** Raw presentation inputs, kept separate from downstream lock and selection readers. */
  #readPresentationArgs?: SelectEngineInit["getArgs"];

  /** Attached after customization setup and before source validation. */
  #readResolvedOptions?: () => SelectConfig;

  /** Raw recipe values remain upstream of option resolution. */
  #readKindOptions?: SelectEngineInit["getKindConfig"];
  #kindOptions?: SelectEngineInit["kindConfig"];
  #readTexts?: SelectEngineInit["getTexts"];
  #readKindTexts?: SelectEngineInit["getKindTexts"];
  #kindTexts?: SelectEngineInit["kindTexts"];
  #readKindTextWrappers?: SelectEngineInit["getKindTextWrappers"];
  #kindTextWrappers?: SelectEngineInit["kindTextWrappers"];
  #valueField: string;
  #normalizeKey?: SelectEngineInit["normalizeKey"];
  #labelField: string;
  // Whether the consumer declared `valueRecords` at all, as opposed to it merely being empty
  // right now. Those are different: an empty-but-declared arg is the late-arrival pattern
  // mid-flight, and the misconfiguration assert must not fire on it.
  #valueRecordsDeclared: boolean;
  #filterBy?: SelectEngineInit["filterBy"];
  #options?: SelectEngineInit["options"];

  /** Each list the caller passed with the entries it was wrapped from, so it is wrapped again only when they change. */
  #wrapped = new WeakMap<
    readonly unknown[],
    { entries: readonly unknown[]; options: readonly SelectOption[] }
  >();

  /** Records that looked like options which were never wrapped, warned about once per engine. */
  #warnedUnwrapped = false;
  #load?: (
    filter: string,
    opts: SelectLoadRequest
  ) => SelectLoadResult | Promise<SelectLoadResult>;
  #readValueRecords?: SelectEngineInit["getValueRecords"];
  #builtValueRecords = new WeakMap<
    SelectValueRecordsBuilder,
    WeakMap<
      object,
      ReturnType<typeof createCache<SelectRecord | SelectRecord[]>>
    >
  >();
  #valueRecords?: SelectEngineInit["valueRecords"];
  #resolveValue?: SelectEngineInit["resolveValue"];
  #resolveValues?: SelectEngineInit["resolveValues"];
  #readAllowCreate?: SelectEngineInit["getAllowCreate"];
  #allowCreate?: SelectEngineInit["allowCreate"];
  #createOption?: SelectEngineInit["createOption"];
  #createUnresolvedRecord?: SelectEngineInit["createUnresolvedRecord"];
  #extraOptions?: SelectEngineInit["extraOptions"];
  #noneOption?: boolean;
  #groupBy?: SelectEngineInit["groupBy"];
  #groupDividers: boolean;
  #groupHeader?: SelectEngineInit["groupHeader"];
  #groupFooter?: SelectEngineInit["groupFooter"];
  #readCloseOnSelect: boolean | undefined;
  #onChange?: SelectEngineInit["onChange"];
  #onReconfirm?: SelectEngineInit["onReconfirm"];
  #onBulkUnchanged?: SelectEngineInit["onBulkUnchanged"];
  #onUpdateStart?: SelectEngineInit["onUpdateStart"];
  #requestClose?: SelectEngineInit["requestClose"];
  #readValue: () => SelectValue;
  #isAsync: boolean;
  #legacy: SelectLegacyContext | null;

  constructor(opts: SelectEngineInit) {
    this.#readMultiple = opts.getMultiple;
    this.#hideSelected = opts.hideSelected;
    this.#readHideSelected = opts.getHideSelected;
    this.#readLocked = opts.getLocked;
    this.#multiple = opts.multiple;
    this.#kind = opts.kind;
    this.#identifier = opts.identifier;
    this.#readKindContext = opts.getKindContext;
    this.#readInstanceContext = opts.getInstanceContext;
    this.#readMinChars = opts.getMinChars;
    this.#minChars = opts.minChars;
    this.#readMaxLoaded = opts.getMaxLoaded;
    this.#maxLoaded = opts.maxLoaded;
    this.#readMaximum = opts.getMaximum;
    this.#maximum = opts.maximum;
    this.#readMinimum = opts.getMinimum;
    this.#minimum = opts.minimum;
    this.#readLockedValues = opts.getLockedValues;
    this.#lockedValues = opts.lockedValues;
    this.#readPresentationArgs = opts.getArgs;
    this.#readKindOptions = opts.getKindConfig;
    this.#kindOptions = opts.kindConfig;
    this.#readTexts = opts.getTexts;
    this.#readKindTexts = opts.getKindTexts;
    this.#kindTexts = opts.kindTexts;
    this.#readKindTextWrappers = opts.getKindTextWrappers;
    this.#kindTextWrappers = opts.kindTextWrappers;
    this.#valueField = opts.valueField ?? "id";
    this.#normalizeKey = opts.normalizeKey;
    this.#labelField = opts.labelField ?? "name";
    // Values are unique by contract (selection identity, row keys), so grouping by the value
    // field deterministically yields one group per row. This certain misuse fails loudly; a
    // function `groupBy` can express the same mapping, but its outcome has no static tell.
    assert(
      `DSelect: \`@groupBy\` ("${String(opts.groupBy)}") is the value field, so every row ` +
        `would become its own group. Group by a coarser key.`,
      typeof opts.groupBy !== "string" || opts.groupBy !== this.#valueField
    );
    this.#filterBy = opts.filterBy;
    this.#options = opts.options;
    assertOptionsList(opts.options);
    this.#load = opts.load;
    this.#readValueRecords = opts.getValueRecords;
    this.#valueRecords = opts.valueRecords;
    this.#valueRecordsDeclared =
      opts.getValueRecords != null || opts.valueRecords != null;
    this.#resolveValue = opts.resolveValue;
    this.#resolveValues = opts.resolveValues;
    this.#readAllowCreate = opts.getAllowCreate;
    this.#allowCreate = opts.allowCreate;
    this.#createOption = opts.createOption;
    this.#createUnresolvedRecord = opts.createUnresolvedRecord;
    this.#extraOptions = opts.extraOptions;
    this.#noneOption = opts.noneOption;
    this.#groupBy = opts.groupBy;
    this.#groupDividers = opts.groupDividers ?? true;
    this.#groupHeader = opts.groupHeader;
    this.#groupFooter = opts.groupFooter;
    // Kept raw (not defaulted here): `closeOnSelect` re-derives `!multiple` live, so a
    // runtime `multiple` flip flips the default close behavior with it.
    this.#readCloseOnSelect = opts.closeOnSelect;
    this.#onChange = opts.onChange;
    this.#onReconfirm = opts.onReconfirm;
    this.#onBulkUnchanged = opts.onBulkUnchanged;
    this.#onUpdateStart = opts.onUpdateStart;
    this.#requestClose = opts.requestClose;
    this.#legacy = opts.legacy ?? null;
    // The controlled value is read live via this thunk, so the engine reflects the
    // parent's `@value` without storing any selection of its own.
    this.#readValue = opts.getValue ?? (() => null);
    this.#isAsync = typeof opts.load === "function";
  }

  /** Whether composed options omit the held selection. */
  get hideSelected(): boolean {
    return this.#readHideSelected?.() ?? this.#hideSelected ?? false;
  }

  get multiple(): boolean {
    return this.#readMultiple?.() ?? this.#multiple ?? false;
  }

  get locked(): boolean {
    return this.#readLocked?.() ?? false;
  }

  get minChars(): number {
    const minChars = this.#readMinChars?.() ?? this.#minChars;
    assert(
      `DSelect: \`@minChars\` (${minChars}) must be 2 or more. Any query of one character ` +
        `already searches, so leave it out for no minimum.`,
      minChars == null || minChars >= 2
    );
    return minChars ?? 0;
  }

  get maxLoaded(): number | undefined {
    return this.#readMaxLoaded?.() ?? this.#maxLoaded;
  }

  /** The single-select none option's label, or `null` while it is off or the select is multiple. */
  get noneLabel(): string | null {
    const config = this.#readResolvedOptions?.();
    if (this.multiple || !config?.noneOption) {
      return null;
    }
    return renderSelectText(config, "noneLabel");
  }

  /** Whether the none option is on when the presentation args don't say. */
  get noneOptionDefault(): boolean | undefined {
    return this.#noneOption;
  }

  /** The call site's live presentation args, before customizations. */
  get presentationArgs(): Readonly<SelectPresentationArgs> {
    return this.#readPresentationArgs?.() ?? {};
  }

  /** The call site's live texts. */
  get texts(): SelectTexts | undefined {
    return this.#readTexts?.();
  }

  /** The recipe's live texts; the customization registry captures their initial keys. */
  get kindTexts(): SelectEngineInit["kindTexts"] {
    return this.#readKindTexts ? this.#readKindTexts() : this.#kindTexts;
  }

  /** The recipe's live text wrappers; their initial keys are captured at construction. */
  get kindTextWrappers(): SelectEngineInit["kindTextWrappers"] {
    return this.#readKindTextWrappers
      ? this.#readKindTextWrappers()
      : this.#kindTextWrappers;
  }

  /** Live recipe base values; the customization registry captures their initial keys. */
  get kindConfig(): Record<string, unknown> | undefined {
    return this.#readKindOptions ? this.#readKindOptions() : this.#kindOptions;
  }

  /** The engine's immutable core and recipe snapshot, for downstream consumers only. */
  get config(): SelectConfig {
    return this.#readResolvedOptions!();
  }

  /** Multi-only; false, numbers below one, and NaN normalize to no cap. */
  get maximum(): number | null {
    const raw = this.#readMaximum?.() ?? this.#maximum;
    if (
      DEBUG &&
      !this.#hasWarnedMaximum &&
      typeof raw === "number" &&
      !(raw >= 1)
    ) {
      this.#hasWarnedMaximum = true;
      warn(
        "DSelect: @maximum below 1 or NaN means no cap. Use @maximum={{false}} for no cap.",
        false,
        { id: "discourse.d-select.maximum-below-one" }
      );
    }
    if (!this.multiple) {
      return null;
    }
    return typeof raw === "number" && raw >= 1 ? Math.floor(raw) : null;
  }

  get minimum(): number {
    if (!this.multiple) {
      return 0;
    }
    const raw = this.#readMinimum?.() ?? this.#minimum;
    return raw != null && raw >= 1 ? Math.floor(raw) : 0;
  }

  /** The held ids no change may drop, as given; validated where they meet the held value. */
  get lockedValues(): unknown {
    return this.#readLockedValues?.() ?? this.#lockedValues;
  }

  get valueRecords(): SelectRecord | SelectRecord[] | undefined {
    const source = this.#readValueRecords?.() ?? this.#valueRecords;
    if (typeof source !== "function") {
      return source;
    }
    // Built once per builder and config snapshot. The cache keeps tracking what the builder
    // reads, so a change there rebuilds it even while the snapshot stays the same.
    const options = this.#readResolvedOptions!();
    let bySnapshot = this.#builtValueRecords.get(source);
    if (!bySnapshot) {
      bySnapshot = new WeakMap();
      this.#builtValueRecords.set(source, bySnapshot);
    }
    let cache = bySnapshot.get(options);
    if (!cache) {
      cache = createCache(() => source(options));
      bySnapshot.set(options, cache);
    }
    return getValue(cache);
  }

  get allowCreate(): SelectEngineInit["allowCreate"] {
    return this.#readAllowCreate?.() ?? this.#allowCreate;
  }

  // Defaults to `!multiple`, re-derived live so a runtime `multiple` flip flips it too.
  get closeOnSelect(): boolean {
    return this.#readCloseOnSelect ?? !this.multiple;
  }

  /** The recipe or family name captured at construction. */
  get kind(): string | undefined {
    return this.#kind;
  }

  /** The call-site name captured at construction. */
  get identifier(): string | undefined {
    return this.#identifier;
  }

  get kindContext(): object {
    return this.#readKindContext?.() ?? EMPTY_CONTEXT;
  }

  get instanceContext(): object {
    return this.#readInstanceContext?.() ?? EMPTY_CONTEXT;
  }

  get valueField(): string {
    return this.#valueField;
  }

  get labelField(): string {
    return this.#labelField;
  }

  get valueRecordsDeclared(): boolean {
    return this.#valueRecordsDeclared;
  }

  get filterBy(): SelectEngineInit["filterBy"] {
    return this.#filterBy;
  }

  get options(): SelectEngineInit["options"] {
    return this.#options;
  }

  get load(): SelectEngineInit["load"] {
    return this.#load;
  }

  get resolveValue(): SelectEngineInit["resolveValue"] {
    return this.#resolveValue;
  }

  get resolveValues(): SelectEngineInit["resolveValues"] {
    return this.#resolveValues;
  }

  get createOption(): SelectEngineInit["createOption"] {
    return this.#createOption;
  }

  get createUnresolvedRecord(): SelectEngineInit["createUnresolvedRecord"] {
    return this.#createUnresolvedRecord;
  }

  get extraOptions(): SelectEngineInit["extraOptions"] {
    return this.#extraOptions;
  }

  get groupBy(): SelectEngineInit["groupBy"] {
    return this.#groupBy;
  }

  get groupDividers(): boolean {
    return this.#groupDividers;
  }

  get groupHeader(): SelectEngineInit["groupHeader"] {
    return this.#groupHeader;
  }

  get groupFooter(): SelectEngineInit["groupFooter"] {
    return this.#groupFooter;
  }

  get onChange(): SelectEngineInit["onChange"] {
    return this.#onChange;
  }

  get onReconfirm(): SelectEngineInit["onReconfirm"] {
    return this.#onReconfirm;
  }

  get onBulkUnchanged(): SelectEngineInit["onBulkUnchanged"] {
    return this.#onBulkUnchanged;
  }

  get onUpdateStart(): SelectEngineInit["onUpdateStart"] {
    return this.#onUpdateStart;
  }

  get requestClose(): SelectEngineInit["requestClose"] {
    return this.#requestClose;
  }

  get value(): SelectValue {
    return this.#readValue();
  }

  get isAsync(): boolean {
    return this.#isAsync;
  }

  get legacy(): SelectLegacyContext | null {
    return this.#legacy;
  }

  /** Connects engine-owned resolution without making raw option reads depend on it. */
  attachResolvedOptions(read: () => SelectConfig): void {
    this.#readResolvedOptions = read;
  }

  /**
   * Two ids denote the same option iff their string forms match after `normalizeKey`, so a
   * bound "5" selects record id 5 (and vice-versa). Nullish never matches an id.
   */
  valueKey(value: SelectId): string | null {
    if (value == null) {
      return null;
    }
    const key = String(value);
    return this.#normalizeKey ? this.#normalizeKey(key) : key;
  }

  /** Removes duplicate normalized ids while preserving first-occurrence order. */
  dedupeValues(values: SelectId[]): SelectId[] {
    const seen = new Set<string | null>();
    return values.filter((value) => {
      const key = this.valueKey(value);
      if (seen.has(key)) {
        return false;
      }
      seen.add(key);
      return true;
    });
  }

  /**
   * Reads a value in single mode. Turning `@multiple` off can leave the parent holding an array,
   * which is read without rewriting the parent's value: empty is no value and one id carries
   * over. More than one is a consumer mistake, so it asserts; production keeps the first.
   *
   * @param raw - The bound value.
   * @returns The single held id, or `null`.
   */
  singleValue(raw: SelectValue | undefined): SelectId | null {
    if (!Array.isArray(raw)) {
      return raw ?? null;
    }
    assert(
      `DSelect: a single-select is holding ${raw.length} values. Pass a single value (or ` +
        `none) to \`@value\` when turning \`@multiple\` off.`,
      raw.length <= 1
    );
    return raw[0] ?? null;
  }

  recordValue(record: SelectRecord | null | undefined): SelectId {
    return record?.[this.#valueField];
  }

  recordLabel(record: SelectRecord | null | undefined): unknown {
    return record?.[this.#labelField];
  }

  /**
   * One entry as an option: an option as it is, a record wrapped with no settings.
   *
   * @param entry - What a list, a builder or a loader returned.
   */
  wrapEntry(entry: SelectOptionLike): SelectOption {
    if (isSelectOption(entry)) {
      return entry as SelectOption;
    }
    this.#warnUnwrapped(entry);
    return selectOption(entry as SelectRecord);
  }

  /**
   * A list as options, one per value: a repeated non-null value keeps the first option. A list
   * the caller passed is wrapped once and the result reused while it holds the same entries,
   * so a list changed in place is wrapped again.
   *
   * @param entries - The records and options to wrap.
   */
  wrapEntries(
    entries: readonly SelectOptionLike[] | null | undefined
  ): readonly SelectOption[] {
    if (entries == null) {
      return [];
    }
    const cached = this.#wrapped.get(entries);
    // Reading every entry also consumes a tracked list's contents, so an edit re-renders.
    if (
      cached &&
      cached.entries.length === entries.length &&
      entries.every((entry, index) => Object.is(entry, cached.entries[index]))
    ) {
      return cached.options;
    }
    const options = this.#wrapList(entries);
    this.#wrapped.set(entries, { entries: [...entries], options });
    return options;
  }

  /**
   * A loaded page as options, without removing repeated values: the paged source does that
   * across every page it holds, so keying the page here too would read each value twice.
   *
   * @param entries - The records and options one page returned.
   */
  wrapPage(entries: readonly SelectOptionLike[]): readonly SelectOption[] {
    const records = DEBUG ? new Set<object>() : undefined;
    return Object.freeze(
      entries.map((entry) => {
        const option = this.wrapEntry(entry);
        if (DEBUG) {
          this.#assertEntry(option, records!);
        }
        return option;
      })
    );
  }

  #wrapList(entries: readonly SelectOptionLike[]): readonly SelectOption[] {
    const keys = new Set<string>();
    const records = DEBUG ? new Set<object>() : undefined;
    const options: SelectOption[] = [];
    for (const entry of entries) {
      const option = this.wrapEntry(entry);
      if (DEBUG) {
        this.#assertEntry(option, records!);
      }
      const key = this.valueKey(this.recordValue(option.record));
      if (key != null) {
        if (keys.has(key)) {
          continue;
        }
        keys.add(key);
      }
      options.push(option);
    }
    return Object.freeze(options);
  }

  /** Development checks for a caller's entry, where the value and label fields are known. */
  #assertEntry(option: SelectOption, records: Set<object>): void {
    const record = option.record;
    assert(
      `DSelect: an option needs its \`${this.#valueField}\` or \`${this.#labelField}\` field. ` +
        "An option spread into an object loses its record; pass the option, or `option.record`.",
      record[this.#valueField] !== undefined ||
        record[this.#labelField] !== undefined
    );
    if (records.has(record)) {
      assert(
        `DSelect: the same record is listed twice ("${String(this.recordLabel(record) ?? this.recordValue(record))}"). ` +
          "Give one record one option.",
        false
      );
    }
    records.add(record);
  }

  /** A bare record shaped like an option almost always means one that should have been wrapped. */
  #warnUnwrapped(entry: SelectOptionLike): void {
    if (!DEBUG || this.#warnedUnwrapped) {
      return;
    }
    const record = entry as SelectRecord;
    if (typeof record?.onSelect === "function" || record?.sticky != null) {
      this.#warnedUnwrapped = true;
      warn(
        "DSelect: a record carries `onSelect` or `sticky`, which are plain data on a record. " +
          'Wrap it to give it settings: `selectOption(record, { onSelect })` or `{ position: "sticky" }`.',
        false,
        { id: "discourse.d-select.unwrapped-option" }
      );
    }
  }
}

/** Legacy select-kit takes a settings hash as `@options`; here it is the list. */
function assertOptionsList(options: unknown): void {
  if (
    options == null ||
    Array.isArray(options) ||
    typeof options === "function"
  ) {
    return;
  }
  assert(
    "DSelect: `@options` is the list of options (an array, or a function returning one), " +
      `not ${Object.prototype.toString.call(options)}; settings are named arguments.`,
    false
  );
}

export { assertOptionsList };
