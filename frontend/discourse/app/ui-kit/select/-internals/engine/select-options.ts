import { assert } from "@ember/debug";
import type {
  SelectPresentationOptions,
  SelectResolvedOptions,
} from "discourse/ui-kit/select/-internals/engine/customizations";
import type {
  SelectEngineOptions,
  SelectItem,
  SelectItemId,
  SelectLegacyContext,
  SelectLoadOptions,
  SelectLoadResult,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** The default `kindContext` and `instanceContext` data when none was provided. */
const EMPTY_CONTEXT: object = Object.freeze({});

/**
 * The engine's live view over its constructor options. Each reactive input is exposed as a
 * getter that reads its thunk on every access (so a runtime change to the wired `@arg`
 * propagates) and falls back to the static option, then the default. Also hosts the pure
 * field-driven helpers (`valueKey`, `itemValue`, `itemLabel`, `dedupeValues`) so every
 * collaborator applies `valueField`/`labelField` identically.
 */
export default class SelectOptionsView {
  #hideSelected?: boolean;
  #readHideSelected?: SelectEngineOptions["getHideSelected"];
  #readMultiple?: SelectEngineOptions["getMultiple"];
  #readLocked?: SelectEngineOptions["getLocked"];
  #multiple?: SelectEngineOptions["multiple"];
  #kind?: string;
  #identifier?: string;
  #readKindContext?: SelectEngineOptions["getKindContext"];
  #readInstanceContext?: SelectEngineOptions["getInstanceContext"];
  #readMinChars?: SelectEngineOptions["getMinChars"];
  #minChars?: SelectEngineOptions["minChars"];
  #readMaximum?: SelectEngineOptions["getMaximum"];
  #maximum?: SelectEngineOptions["maximum"];
  #readMinimum?: SelectEngineOptions["getMinimum"];
  #minimum?: SelectEngineOptions["minimum"];
  #readNoneLabel?: SelectEngineOptions["getNoneLabel"];
  #noneLabel?: SelectEngineOptions["noneLabel"];

  /** Raw presentation inputs, kept separate from downstream lock and selection readers. */
  #readPresentationOptions?: SelectEngineOptions["getOptions"];

  /** Attached after customization setup and before source validation. */
  #readResolvedOptions?: () => SelectResolvedOptions;

  /** Raw recipe values remain upstream of option resolution. */
  #readKindOptions?: SelectEngineOptions["getKindOptions"];
  #kindOptions?: SelectEngineOptions["kindOptions"];
  #valueField: string;
  #labelField: string;
  // Whether the consumer declared `valueItems` at all, as opposed to it merely being empty
  // right now. Those are different: an empty-but-declared arg is the late-arrival pattern
  // mid-flight, and the misconfiguration assert must not fire on it.
  #valueItemsDeclared: boolean;
  #filterBy?: SelectEngineOptions["filterBy"];
  #items?: SelectEngineOptions["items"];
  #load?: (
    filter: string,
    opts: SelectLoadOptions
  ) => SelectLoadResult | Promise<SelectLoadResult>;
  #readValueItems?: SelectEngineOptions["getValueItems"];
  #valueItems?: SelectEngineOptions["valueItems"];
  #resolveValue?: SelectEngineOptions["resolveValue"];
  #resolveValues?: SelectEngineOptions["resolveValues"];
  #readAllowCreate?: SelectEngineOptions["getAllowCreate"];
  #allowCreate?: SelectEngineOptions["allowCreate"];
  #createItem?: SelectEngineOptions["createItem"];
  #createUnresolvedItem?: SelectEngineOptions["createUnresolvedItem"];
  #specialItems?: SelectEngineOptions["specialItems"];
  #groupBy?: SelectEngineOptions["groupBy"];
  #groupLabelFn?: SelectEngineOptions["groupLabel"];
  #readCloseOnSelect: boolean | undefined;
  #onChange?: SelectEngineOptions["onChange"];
  #onReconfirm?: SelectEngineOptions["onReconfirm"];
  #onUpdateStart?: SelectEngineOptions["onUpdateStart"];
  #requestClose?: SelectEngineOptions["requestClose"];
  #readValue: () => SelectValue;
  #isAsync: boolean;
  #legacy: SelectLegacyContext | null;

  constructor(opts: SelectEngineOptions) {
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
    this.#readMaximum = opts.getMaximum;
    this.#maximum = opts.maximum;
    this.#readMinimum = opts.getMinimum;
    this.#minimum = opts.minimum;
    this.#readNoneLabel = opts.getNoneLabel;
    this.#noneLabel = opts.noneLabel;
    this.#readPresentationOptions = opts.getOptions;
    this.#readKindOptions = opts.getKindOptions;
    this.#kindOptions = opts.kindOptions;
    this.#valueField = opts.valueField ?? "id";
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
    this.#items = opts.items;
    this.#load = opts.load;
    this.#readValueItems = opts.getValueItems;
    this.#valueItems = opts.valueItems;
    this.#valueItemsDeclared =
      opts.getValueItems != null || opts.valueItems != null;
    this.#resolveValue = opts.resolveValue;
    this.#resolveValues = opts.resolveValues;
    this.#readAllowCreate = opts.getAllowCreate;
    this.#allowCreate = opts.allowCreate;
    this.#createItem = opts.createItem;
    this.#createUnresolvedItem = opts.createUnresolvedItem;
    this.#specialItems = opts.specialItems;
    this.#groupBy = opts.groupBy;
    this.#groupLabelFn = opts.groupLabel;
    // Kept raw (not defaulted here): `closeOnSelect` re-derives `!multiple` live, so a
    // runtime `multiple` flip flips the default close behavior with it.
    this.#readCloseOnSelect = opts.closeOnSelect;
    this.#onChange = opts.onChange;
    this.#onReconfirm = opts.onReconfirm;
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
    return this.#readMinChars?.() ?? this.#minChars ?? 0;
  }

  /** Raw none label for options resolution, independent of the overlay and multiple mode. */
  get baseNoneLabel(): string | undefined {
    return this.#readNoneLabel?.() ?? this.#noneLabel;
  }

  /** Customized single-select none label; empty labels and multiple mode suppress the row. */
  get noneLabel(): string | null {
    if (this.multiple) {
      return null;
    }
    const label = this.#readResolvedOptions?.().noneLabel ?? this.baseNoneLabel;
    return label ? label : null;
  }

  /** The call site's live presentation args, before customizations. */
  get presentationOptions(): Readonly<SelectPresentationOptions> {
    return this.#readPresentationOptions?.() ?? {};
  }

  /** Live recipe base values; the customization registry captures their initial keys. */
  get kindOptions(): Record<string, unknown> | undefined {
    return this.#readKindOptions ? this.#readKindOptions() : this.#kindOptions;
  }

  /** The engine's immutable core and recipe snapshot, for downstream consumers only. */
  get resolvedOptions(): SelectResolvedOptions {
    return this.#readResolvedOptions!();
  }

  // Multi-only, and `null` for anything below one — which also absorbs `0`, negatives, and
  // `NaN`, all of which mean "no cap" rather than "cap of nothing".
  get maximum(): number | null {
    if (!this.multiple) {
      return null;
    }
    const raw = this.#readMaximum?.() ?? this.#maximum;
    return raw != null && raw >= 1 ? Math.floor(raw) : null;
  }

  get minimum(): number {
    if (!this.multiple) {
      return 0;
    }
    const raw = this.#readMinimum?.() ?? this.#minimum;
    return raw != null && raw >= 1 ? Math.floor(raw) : 0;
  }

  get valueItems(): SelectItem | SelectItem[] | undefined {
    return this.#readValueItems?.() ?? this.#valueItems;
  }

  get allowCreate(): SelectEngineOptions["allowCreate"] {
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

  get valueItemsDeclared(): boolean {
    return this.#valueItemsDeclared;
  }

  get filterBy(): SelectEngineOptions["filterBy"] {
    return this.#filterBy;
  }

  get items(): SelectEngineOptions["items"] {
    return this.#items;
  }

  get load(): SelectEngineOptions["load"] {
    return this.#load;
  }

  get resolveValue(): SelectEngineOptions["resolveValue"] {
    return this.#resolveValue;
  }

  get resolveValues(): SelectEngineOptions["resolveValues"] {
    return this.#resolveValues;
  }

  get createItem(): SelectEngineOptions["createItem"] {
    return this.#createItem;
  }

  get createUnresolvedItem(): SelectEngineOptions["createUnresolvedItem"] {
    return this.#createUnresolvedItem;
  }

  get specialItems(): SelectEngineOptions["specialItems"] {
    return this.#specialItems;
  }

  get groupBy(): SelectEngineOptions["groupBy"] {
    return this.#groupBy;
  }

  get groupLabel(): SelectEngineOptions["groupLabel"] {
    return this.#groupLabelFn;
  }

  get onChange(): SelectEngineOptions["onChange"] {
    return this.#onChange;
  }

  get onReconfirm(): SelectEngineOptions["onReconfirm"] {
    return this.#onReconfirm;
  }

  get onUpdateStart(): SelectEngineOptions["onUpdateStart"] {
    return this.#onUpdateStart;
  }

  get requestClose(): SelectEngineOptions["requestClose"] {
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
  attachResolvedOptions(read: () => SelectResolvedOptions): void {
    this.#readResolvedOptions = read;
  }

  // Two ids denote the same option iff their string forms match, so a bound "5" selects
  // item id 5 (and vice-versa). Nullish never matches an id.
  valueKey(value: SelectItemId): string | null {
    return value == null ? null : String(value);
  }

  /** Removes duplicate normalized ids while preserving first-occurrence order. */
  dedupeValues(values: SelectItemId[]): SelectItemId[] {
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
  singleValue(raw: SelectValue | undefined): SelectItemId | null {
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

  itemValue(item: SelectItem | null | undefined): SelectItemId {
    return item?.[this.#valueField];
  }

  itemLabel(item: SelectItem | null | undefined): unknown {
    return item?.[this.#labelField];
  }
}
