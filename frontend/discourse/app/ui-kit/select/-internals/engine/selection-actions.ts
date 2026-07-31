import { makeArray } from "discourse/lib/helpers";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import type {
  SelectItem,
  SelectItemId,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import type SelectOptionsView from "./select-options";

export default class SelectionActions {
  #options: SelectOptionsView;
  #runActionItem: (item: SelectItem) => void;
  #cacheResolved: (item: SelectItem | null | undefined) => void;
  #resolveOneSync: (value: SelectItemId) => SelectItem | undefined;
  #applyLegacyOnChange: (
    value: SelectValue,
    payload: SelectItem | SelectItem[] | null
  ) => void;

  constructor(opts: {
    options: SelectOptionsView;
    runActionItem: (item: SelectItem) => void;
    cacheResolved: (item: SelectItem | null | undefined) => void;
    resolveOneSync: (value: SelectItemId) => SelectItem | undefined;
    applyLegacyOnChange: (
      value: SelectValue,
      payload: SelectItem | SelectItem[] | null
    ) => void;
  }) {
    this.#options = opts.options;
    this.#runActionItem = opts.runActionItem;
    this.#cacheResolved = opts.cacheResolved;
    this.#resolveOneSync = opts.resolveOneSync;
    this.#applyLegacyOnChange = opts.applyLegacyOnChange;
  }

  /**
   * The controlled value, normalized. Not cached: it reads the live `getValue` thunk
   * so it always reflects the parent's `@value` (which is what makes the component
   * controlled). For a stable `@context` identity, feed the raw `@value` to the trigger
   * rather than this getter.
   *
   * @returns A frozen id array (multiple) or a single id / `null`.
   */
  get value(): SelectValue {
    const raw = this.#options.value;
    return this.#options.multiple
      ? Object.freeze(
          this.#options.dedupeValues(makeArray(raw) as SelectItemId[])
        )
      : (raw ?? null);
  }

  /** Whether anything is selected. */
  get hasValue(): boolean {
    return this.#options.multiple
      ? this.#valueArray.length > 0
      : this.value != null;
  }

  /** The multi-select selection cap, or `null` when uncapped (always `null` for single). */
  get maximum(): number | null {
    return this.#options.maximum;
  }

  /** The advisory multi-select minimum (`0` = none, and always `0` for single). */
  get minimum(): number {
    return this.#options.minimum;
  }

  /**
   * Whether the selection has reached {@link maximum}. At the cap no further item can be
   * added, and every unselected ordinary option reports itself disabled.
   */
  get atMaximum(): boolean {
    return this.#atMaximum;
  }

  /** Whether the selection is still short of the advisory {@link minimum}. */
  get belowMinimum(): boolean {
    const minimum = this.#options.minimum;
    return minimum > 0 && this.#selectedCount < minimum;
  }

  /** How many more items may still be added, or `undefined` when uncapped. */
  get remaining(): number | undefined {
    const maximum = this.#options.maximum;
    return maximum == null
      ? undefined
      : Math.max(0, maximum - this.#selectedCount);
  }

  /**
   * Finds the first value added and removed between two selections. Comparison deliberately
   * uses `String(value)`, including for nullish values, rather than the option identity key.
   */
  diffValues(
    previous: SelectItemId[],
    next: SelectItemId[]
  ): {
    added: SelectItemId | undefined;
    removed: SelectItemId | undefined;
  } {
    const previousKeys = new Set(previous.map(String));
    const nextKeys = new Set(next.map(String));
    return Object.freeze({
      added: next.find((value) => !previousKeys.has(String(value))),
      removed: previous.find((value) => !nextKeys.has(String(value))),
    });
  }

  /**
   * Whether an item is currently selected, comparing its `valueField` id against the
   * controlled value.
   */
  isSelected(item: SelectItem): boolean {
    // The "none" row stands in for the empty selection, so it reads as selected exactly when
    // nothing else is. Single-select only, and resolved before the key lookup — its value is
    // `null`, which the comparison below would otherwise reject as unselectable.
    if (item.__none && !this.#options.multiple) {
      return !this.hasValue;
    }
    const key = this.#options.valueKey(this.#options.itemValue(item));
    if (key == null) {
      return false;
    }
    return this.#options.multiple
      ? this.#valueArray.some((v) => this.#options.valueKey(v) === key)
      : this.#options.valueKey(this.value) === key;
  }

  /**
   * Activates an item: runs its `onSelect` callback if present (an action item that
   * never becomes a value and does not close the overlay), otherwise toggles it.
   */
  activate(item: SelectItem): void {
    if (typeof item?.onSelect === "function") {
      this.#runActionItem(item);
      return;
    }
    this.toggle(item);
  }

  /**
   * Toggles an item: for multi, selects or deselects; for single, selects it.
   */
  toggle(item: SelectItem): void {
    if (this.#options.multiple && this.isSelected(item)) {
      this.deselect(item);
    } else {
      this.select(item);
    }
  }

  /**
   * Selects an item: caches it for synchronous display, computes the next value, and
   * emits `onChange`. For single-select it also requests the overlay to close (when
   * `closeOnSelect`). Never mutates the value — the parent does, via `onChange`.
   */
  select(item: SelectItem): void {
    if (this.isSelected(item)) {
      // Re-picking the current value is a confirmation, not a change: emit nothing, but still
      // close. Since the list restores the cursor to the selected option, this is the first
      // keystroke after opening, and leaving it inert would read as a broken control.
      if (!this.#options.multiple && this.#options.closeOnSelect) {
        this.#options.requestClose?.();
      }
      return;
    }
    // The item is known to be unselected here, so this rejects genuine additions only. It is
    // the single chokepoint every add reaches — pointer, keyboard, create-on-the-fly, and the
    // compat bridge — so the cap cannot be walked around, and rejecting before the resolve
    // cache leaves no trace of a selection that never happened.
    if (this.#atMaximum) {
      return;
    }
    this.#cacheResolved(item);
    if (this.#options.multiple) {
      this.#emitChange([...this.#valueArray, this.#options.itemValue(item)]);
    } else {
      this.#emitChange(this.#options.itemValue(item));
      if (this.#options.closeOnSelect) {
        this.#options.requestClose?.();
      }
    }
  }

  /**
   * Removes an item from the selection (emits the next value).
   */
  deselect(item: SelectItem): void {
    if (!this.#options.multiple) {
      this.#emitChange(null);
      return;
    }
    const key = this.#options.valueKey(this.#options.itemValue(item));
    this.#emitChange(
      this.#valueArray.filter((v) => this.#options.valueKey(v) !== key)
    );
  }

  /** Removes the last held value from a multi-select selection. */
  deselectLast(): void {
    if (!this.#options.multiple) {
      return;
    }
    const values = this.#valueArray;
    if (values.length === 0) {
      return;
    }
    this.#emitChange(values.slice(0, -1));
  }

  /**
   * Clears the entire selection (emits an empty value).
   */
  clear(): void {
    this.#emitChange(this.#options.multiple ? [] : null);
  }

  /**
   * The count the limits are measured against: every held id, deduped. A nullish entry counts
   * like any other — it still resolves to a displayed, removable chip, so excluding it would
   * let the visible selection exceed the cap, and the user can always reclaim its slot by
   * removing that chip.
   */
  get #selectedCount(): number {
    return this.#valueArray.length;
  }

  get #atMaximum(): boolean {
    const maximum = this.#options.maximum;
    return maximum != null && this.#selectedCount >= maximum;
  }

  /**
   * The current value coerced to its multi-select array form. Only meaningful when
   * `#options.multiple` (the single-select value is never read through here); it centralizes
   * the one place the union `value` is treated as an array so the multi-only call sites
   * stay narrowing-free.
   */
  get #valueArray(): readonly SelectItemId[] {
    return this.value as readonly SelectItemId[];
  }

  // Emits the next value plus the best-effort resolved item(s) for it. Controlled: the
  // engine never stores the value — the parent applies `nextValue` to `@value`.
  #emitChange(rawNextValue: SelectValue): void {
    // Coerce ids to their source item's native type up front, so the payload, the
    // `select-on-change` transformer context, and the legacy bridge all emit one consistent,
    // single-typed value rather than a parent/URL-typed held id mixed with a freshly-picked
    // native one.
    const nextValue = this.#coerceValue(rawNextValue);
    const items = this.#itemsFor(nextValue);
    const payload = this.#options.multiple ? items : (items[0] ?? null);

    // The selection-side-effect extension point: the default behavior emits the
    // controlled `onChange`; registered `select-on-change` transformers wrap it (and
    // may run `next()` to proceed or skip it).
    applyBehaviorTransformer(
      "select-on-change",
      () => this.#options.onChange?.(nextValue, payload),
      {
        identifiers: this.#options.identifiers,
        value: nextValue,
        items: payload,
      }
    );

    // Legacy `modifySelectKit(id).onChange` extensions (side effects only, run after
    // the value has changed — matching the old ordering).
    this.#applyLegacyOnChange(nextValue, payload);
  }

  // Best-effort synchronous resolution of a value to its item(s), from the escape
  // hatch / cache / client list — never async (this feeds the `onChange` payload).
  #itemsFor(value: SelectValue): SelectItem[] {
    const values: SelectItemId[] =
      value == null
        ? []
        : this.#options.multiple
          ? (makeArray(value) as SelectItemId[])
          : [value];
    return values
      .map((v) => this.#resolveOneSync(v))
      .filter((item): item is SelectItem => item != null);
  }

  // Multi-select only: re-emit each id in its resolved source item's native type, so a held
  // parent/URL-typed id (a string `"5"`) and a freshly-picked native id (`3`) never leave as a
  // mixed-type array. An id that resolves to no known item passes through unchanged — its type is
  // unknowable — and order is preserved. Single-select already emits the native id, so its value
  // is returned untouched. Matching is by string form, so coercion never changes which option is
  // selected, only the emitted type.
  #coerceValue(value: SelectValue): SelectValue {
    if (!this.#options.multiple || value == null) {
      return value;
    }
    return (makeArray(value) as SelectItemId[]).map((id) => {
      const item = this.#resolveOneSync(id);
      return item ? this.#options.itemValue(item) : id;
    });
  }
}
