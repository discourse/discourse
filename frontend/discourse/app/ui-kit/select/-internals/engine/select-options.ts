import { assert } from "@ember/debug";
import { makeArray } from "discourse/lib/helpers";
import type {
  SelectEngineOptions,
  SelectItem,
  SelectItemId,
  SelectLegacyContext,
  SelectLoadOptions,
  SelectLoadResult,
  SelectSnapshot,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

/**
 * The engine's live view over its constructor options. Each reactive input is exposed as a
 * getter that reads its thunk on every access (so a runtime change to the wired `@arg`
 * propagates) and falls back to the static option, then the default. Also hosts the pure
 * field-driven helpers (`valueKey`, `itemValue`, `itemLabel`, `dedupeValues`) so every
 * collaborator applies `valueField`/`labelField` identically.
 */
export default class SelectOptionsView {
  #readMultiple?: SelectEngineOptions["getMultiple"];
  #multiple?: SelectEngineOptions["multiple"];
  #identifiers: string[];
  #readMinChars?: SelectEngineOptions["getMinChars"];
  #minChars?: SelectEngineOptions["minChars"];
  #readMaximum?: SelectEngineOptions["getMaximum"];
  #maximum?: SelectEngineOptions["maximum"];
  #readMinimum?: SelectEngineOptions["getMinimum"];
  #minimum?: SelectEngineOptions["minimum"];
  #readNoneLabel?: SelectEngineOptions["getNoneLabel"];
  #noneLabel?: SelectEngineOptions["noneLabel"];
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
  #specialItems?: (snapshot: SelectSnapshot) => SelectItem[];
  #groupBy?: SelectEngineOptions["groupBy"];
  #groupLabelFn?: SelectEngineOptions["groupLabel"];
  #readCloseOnSelect: boolean | undefined;
  #onChange?: SelectEngineOptions["onChange"];
  #requestClose?: SelectEngineOptions["requestClose"];
  #readValue: () => SelectValue;
  #isAsync: boolean;
  #legacy: SelectLegacyContext | null;

  constructor(opts: SelectEngineOptions) {
    this.#readMultiple = opts.getMultiple;
    this.#multiple = opts.multiple;
    this.#identifiers = makeArray(opts.identifiers) as string[];
    this.#readMinChars = opts.getMinChars;
    this.#minChars = opts.minChars;
    this.#readMaximum = opts.getMaximum;
    this.#maximum = opts.maximum;
    this.#readMinimum = opts.getMinimum;
    this.#minimum = opts.minimum;
    this.#readNoneLabel = opts.getNoneLabel;
    this.#noneLabel = opts.noneLabel;
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
    this.#requestClose = opts.requestClose;
    this.#legacy = opts.legacy ?? null;
    // The controlled value is read live via this thunk, so the engine reflects the
    // parent's `@value` without storing any selection of its own.
    this.#readValue = opts.getValue ?? (() => null);
    this.#isAsync = typeof opts.load === "function";
  }

  get multiple(): boolean {
    return this.#readMultiple?.() ?? this.#multiple ?? false;
  }

  get minChars(): number {
    return this.#readMinChars?.() ?? this.#minChars ?? 0;
  }

  // Single-select only: the label for the prepended "none" row, or `null` when unset/empty or on a
  // multi-select (there "none" is the placeholder, not a row). Gating multi here keeps every
  // downstream consumer — injection and the `isSelected` special-case — inert on multi.
  get noneLabel(): string | null {
    if (this.multiple) {
      return null;
    }
    const label = this.#readNoneLabel?.() ?? this.#noneLabel;
    return label ? label : null;
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

  get allowCreate():
    | boolean
    | ((filter: string, items: SelectItem[]) => boolean)
    | undefined {
    return this.#readAllowCreate?.() ?? this.#allowCreate;
  }

  // Defaults to `!multiple`, re-derived live so a runtime `multiple` flip flips it too.
  get closeOnSelect(): boolean {
    return this.#readCloseOnSelect ?? !this.multiple;
  }

  get identifiers(): string[] {
    return this.#identifiers;
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

  itemValue(item: SelectItem | null | undefined): SelectItemId {
    return item?.[this.#valueField];
  }

  itemLabel(item: SelectItem | null | undefined): unknown {
    return item?.[this.#labelField];
  }
}
