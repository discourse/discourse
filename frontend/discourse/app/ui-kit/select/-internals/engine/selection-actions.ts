import { cached } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { makeArray } from "discourse/lib/helpers";
import type {
  SelectId,
  SelectRecord,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";
import type { SelectChangeContext } from "./customizations.ts";
import type SelectArgsView from "./select-args.ts";
import {
  entryRecord,
  isSelectOption,
  optionKind,
  type SelectOption,
  type SelectOptionLike,
} from "./select-option.ts";
import type { SelectionOrigin } from "./selection-updates.ts";

/** The option an entry was passed as, if it was one. A bare record has no settings. */
function optionOf(entry: SelectOptionLike): SelectOption | undefined {
  return isSelectOption(entry) ? (entry as SelectOption) : undefined;
}

/** Whether an option can become a value: not disabled, not an action, not a drawn line. */
function isPickable(option: SelectOption | undefined): boolean {
  if (!option) {
    return true;
  }
  const kind = optionKind(option);
  return (
    !option.disabled &&
    !option.action &&
    kind !== "text-header" &&
    kind !== "text-footer" &&
    kind !== "divider"
  );
}

/** The held locked keys, and why the input breaks the contract when it does. */
type LockedKeys = {
  keys: ReadonlySet<string | null>;
  problem?: string;
};

const NO_LOCKED_KEYS: LockedKeys = Object.freeze({
  keys: Object.freeze(new Set<string | null>()),
});

export default class SelectionActions {
  #args: SelectArgsView;
  #onIntent: (origin?: SelectionOrigin) => void;
  #beforeEmit: (
    origin: SelectionOrigin | undefined,
    value: SelectValue
  ) => boolean;
  #runAction: (option: SelectOption) => void;
  #cacheResolved: (record: SelectRecord | null | undefined) => void;
  #resolveOneSync: (value: SelectId) => SelectRecord | undefined;
  #applyLegacyOnChange: (
    value: SelectValue,
    payload: SelectRecord | SelectRecord[] | null
  ) => void;
  #getExtensionContext: () => Omit<SelectChangeContext, "value" | "records">;

  /** Runs the once-only change queue around the guarded controlled emit. */
  #runChange: (
    defaultStep: () => void,
    context: SelectChangeContext
  ) => void | Promise<void>;

  constructor(opts: {
    args: SelectArgsView;
    onIntent: (origin?: SelectionOrigin) => void;
    beforeEmit: (
      origin: SelectionOrigin | undefined,
      value: SelectValue
    ) => boolean;
    runAction: (option: SelectOption) => void;
    cacheResolved: (record: SelectRecord | null | undefined) => void;
    resolveOneSync: (value: SelectId) => SelectRecord | undefined;
    applyLegacyOnChange: (
      value: SelectValue,
      payload: SelectRecord | SelectRecord[] | null
    ) => void;
    getExtensionContext: () => Omit<SelectChangeContext, "value" | "records">;
    /** Applies sealed per-select change declarations. */
    runChange: (
      defaultStep: () => void,
      context: SelectChangeContext
    ) => void | Promise<void>;
  }) {
    this.#args = opts.args;
    this.#onIntent = opts.onIntent;
    this.#beforeEmit = opts.beforeEmit;
    this.#runAction = opts.runAction;
    this.#cacheResolved = opts.cacheResolved;
    this.#resolveOneSync = opts.resolveOneSync;
    this.#applyLegacyOnChange = opts.applyLegacyOnChange;
    this.#getExtensionContext = opts.getExtensionContext;
    this.#runChange = opts.runChange;
  }

  /**
   * Reads the live mode, sharing normalization across reads and list rebuilds.
   *
   * @returns A frozen id array (multiple) or a single id / `null`.
   */
  get value(): SelectValue {
    return this.#args.multiple ? this._valueArray : this._singleValue;
  }

  /** Whether anything is selected. */
  get hasValue(): boolean {
    return this.#args.multiple
      ? this._valueArray.length > 0
      : this.value != null;
  }

  /** The multi-select selection cap, or `null` when uncapped (always `null` for single). */
  get maximum(): number | null {
    return this.#args.maximum;
  }

  /** The advisory multi-select minimum (`0` = none, and always `0` for single). */
  get minimum(): number {
    return this.#args.minimum;
  }

  /** Whether anything held can be removed: a held value that isn't locked. */
  get hasRemovableValue(): boolean {
    if (!this.#args.multiple) {
      return this.hasValue;
    }
    return this._valueArray.some((value) => !this.isLockedValue(value));
  }

  /**
   * Whether the selection has reached {@link maximum}. At the cap no further record can be
   * added, and every unselected ordinary option reports itself disabled.
   */
  get atMaximum(): boolean {
    return this.#atMaximum;
  }

  /** Whether the selection is still short of the advisory {@link minimum}. */
  get belowMinimum(): boolean {
    const minimum = this.#args.minimum;
    return minimum > 0 && this.selectedCount < minimum;
  }

  /**
   * The count the limits are measured against: every held id, deduped. A nullish entry counts
   * like any other — it still resolves to a displayed, removable chip, so excluding it would
   * let the visible selection exceed the cap, and the user can always reclaim its slot by
   * removing that chip.
   */
  get selectedCount(): number {
    return this._valueArray.length;
  }

  /** How many more records may still be added, or `undefined` when uncapped. */
  get remaining(): number | undefined {
    const maximum = this.#args.maximum;
    return maximum == null
      ? undefined
      : Math.max(0, maximum - this.selectedCount);
  }

  get #atMaximum(): boolean {
    const maximum = this.#args.maximum;
    return maximum != null && this.selectedCount >= maximum;
  }

  get #lockedKeys(): ReadonlySet<string | null> {
    const { keys, problem } = this._lockedKeys;
    assert(problem ?? "", !problem);
    return keys;
  }

  @cached
  get _selectedKeys(): ReadonlySet<string | null> {
    return new Set(this._valueArray.map((value) => this.#args.valueKey(value)));
  }

  /**
   * The held ids no change may drop. Only held ids count, so a contract breach reported in
   * development behaves in production as if the unheld ids were never given.
   */
  @cached
  get _lockedKeys(): LockedKeys {
    const locked = this.#args.lockedValues;
    if (locked == null) {
      return NO_LOCKED_KEYS;
    }
    if (!Array.isArray(locked)) {
      return {
        ...NO_LOCKED_KEYS,
        problem: "DSelect: `@lockedValues` must be an array of held ids.",
      };
    }
    if (locked.length === 0) {
      return NO_LOCKED_KEYS;
    }
    if (!this.#args.multiple) {
      return {
        ...NO_LOCKED_KEYS,
        problem:
          "DSelect: `@lockedValues` needs `@multiple`. Use `@readonly` for a single value that can't change.",
      };
    }
    const held = this._selectedKeys;
    const keys = new Set<string | null>();
    const unheld: SelectId[] = [];
    for (const value of locked as SelectId[]) {
      const key = this.#args.valueKey(value);
      if (held.has(key)) {
        keys.add(key);
      } else {
        unheld.push(value);
      }
    }
    return {
      keys,
      problem:
        unheld.length === 0
          ? undefined
          : `DSelect: the locked value "${String(unheld[0])}" is not in \`@value\`. ` +
            "`@lockedValues` must be a subset of `@value`.",
    };
  }

  @cached
  get _singleValue(): SelectId | null {
    return this.#args.singleValue(this.#args.value);
  }

  @cached
  get _valueArray(): readonly SelectId[] {
    return Object.freeze(
      this.#args.dedupeValues(makeArray(this.#args.value) as SelectId[])
    );
  }

  /** Whether a held value is locked, matching ids by their key. */
  isLockedValue(value: SelectId): boolean {
    return this.#lockedKeys.has(this.#args.valueKey(value));
  }

  /** Every value in `previous` whose key `next` no longer holds, in held order. */
  removedValues(
    previous: readonly SelectId[],
    next: readonly SelectId[]
  ): SelectId[] {
    const nextKeys = new Set(next.map((value) => this.#args.valueKey(value)));
    return previous.filter(
      (value) => !nextKeys.has(this.#args.valueKey(value))
    );
  }

  /**
   * Finds the first value added and removed between two selections. Comparison deliberately
   * uses `String(value)`, including for nullish values, rather than the option identity key.
   */
  diffValues(
    previous: SelectId[],
    next: SelectId[]
  ): {
    added: SelectId | undefined;
    removed: SelectId | undefined;
  } {
    const previousKeys = new Set(previous.map(String));
    const nextKeys = new Set(next.map(String));
    return Object.freeze({
      added: next.find((value) => !previousKeys.has(String(value))),
      removed: previous.find((value) => !nextKeys.has(String(value))),
    });
  }

  /**
   * Whether a record or option is currently selected, comparing its record's `valueField` id
   * against the controlled value.
   */
  isSelected(entry: SelectOptionLike): boolean {
    // The none option stands in for the empty selection, so it reads as selected exactly when
    // nothing else is. Single-select only, and resolved before the key lookup — its value is
    // `null`, which the comparison below would otherwise reject as unselectable.
    if (optionOf(entry)?.none && !this.#args.multiple) {
      return !this.hasValue;
    }
    const key = this.#args.valueKey(this.#args.recordValue(entryRecord(entry)));
    if (key == null) {
      return false;
    }
    return this.#args.multiple
      ? this._selectedKeys.has(key)
      : this.#args.valueKey(this.value) === key;
  }

  /**
   * Activates an option: runs its `onSelect` if it is an action (which never becomes a value
   * and does not close the overlay), otherwise toggles its record.
   */
  activate(entry: SelectOptionLike): void {
    const option = optionOf(entry);
    if (option?.action) {
      this.#runAction(option);
      return;
    }
    this.toggle(entry);
  }

  /**
   * Toggles a record: for multi, selects or deselects; for single, selects it.
   */
  toggle(entry: SelectOptionLike): void {
    if (this.#args.locked) {
      return;
    }
    if (this.#args.multiple && this.isSelected(entry)) {
      this.deselect(entry);
    } else {
      this.select(entry);
    }
  }

  /**
   * Selects a record: caches it for synchronous display, computes the next value, and emits
   * `onChange`. An option passed instead is honoured: a disabled one selects nothing, and an
   * action can't be selected. For single-select it also requests the overlay to close (when
   * `closeOnSelect`). Never mutates the value — the parent does, via `onChange`.
   */
  select(entry: SelectOptionLike, origin?: SelectionOrigin): void {
    const option = optionOf(entry);
    assert(
      "DSelect: an action option runs its `onSelect` when picked; it can't be selected as a value.",
      !option?.action
    );
    this.#onIntent(origin);
    if (this.#args.locked || option?.disabled) {
      return;
    }
    const record = entryRecord(entry);
    if (this.isSelected(entry)) {
      if (origin) {
        this.#args.onReconfirm?.(record, origin);
      }
      // Re-picking the current value is a confirmation, not a change: emit nothing, but still
      // close. Since the list restores the cursor to the selected option, this is the first
      // keystroke after opening, and leaving it inert would read as a broken control.
      if (!this.#args.multiple && this.#args.closeOnSelect) {
        this.#args.requestClose?.();
      }
      return;
    }
    // The record is known to be unselected here, so this rejects genuine additions only. It is
    // the single chokepoint every add reaches — pointer, keyboard, create-on-the-fly, and the
    // compat bridge — so the cap cannot be walked around, and rejecting before the resolve
    // cache leaves no trace of a selection that never happened.
    if (this.#atMaximum) {
      return;
    }
    this.#cacheResolved(record);
    if (this.#args.multiple) {
      this.#emitChange(
        [...this._valueArray, this.#args.recordValue(record)],
        origin
      );
    } else {
      this.#emitChange(this.#args.recordValue(record), origin);
      if (this.#args.closeOnSelect) {
        this.#args.requestClose?.();
      }
    }
  }

  /** Adds a batch without losing its update authority during middleware or deferred emits. */
  selectMany(
    entries: readonly SelectOptionLike[],
    origin?: SelectionOrigin
  ): void {
    this.#onIntent(origin);
    if (this.#args.locked) {
      return;
    }

    const seen = new Set<string>();
    const additions: SelectRecord[] = [];
    let held = 0;
    let limit = 0;
    const remaining = this.remaining;
    for (const entry of entries) {
      if (!isPickable(optionOf(entry))) {
        continue;
      }
      const record = entryRecord(entry);
      const key = this.#args.valueKey(this.#args.recordValue(record));
      if (key == null) {
        continue;
      }
      if (this.isSelected(record) || seen.has(key)) {
        held++;
        continue;
      }
      seen.add(key);
      if (!this.#args.multiple) {
        this.select(record, origin);
        return;
      }
      if (remaining !== undefined && additions.length >= remaining) {
        limit++;
        continue;
      }
      additions.push(record);
    }
    if (additions.length === 0) {
      if (held + limit > 0) {
        this.#args.onBulkUnchanged?.({ held, limit });
      }
      return;
    }
    for (const record of additions) {
      this.#cacheResolved(record);
    }
    this.#emitChange(
      [
        ...this._valueArray,
        ...additions.map((record) => this.#args.recordValue(record)),
      ],
      {
        ...(origin ?? { programmatic: true }),
        bulk: { added: additions.length, held, limit },
      }
    );
  }

  /**
   * Removes a record from the selection (emits the next value).
   */
  deselect(entry: SelectOptionLike, origin?: SelectionOrigin): void {
    this.#onIntent(origin);
    if (this.#args.locked) {
      return;
    }
    if (!this.#args.multiple) {
      if (origin && !this.isSelected(entry)) {
        return;
      }
      this.#emitChange(null, origin);
      return;
    }
    const value = this.#args.recordValue(entryRecord(entry));
    if (this.isLockedValue(value)) {
      return;
    }
    const key = this.#args.valueKey(value);
    this.#emitChange(
      this._valueArray.filter((v) => this.#args.valueKey(v) !== key),
      origin
    );
  }

  /** Removes the last held value from a multi-select selection. */
  deselectLast(origin?: SelectionOrigin): void {
    this.#onIntent(origin);
    if (this.#args.locked || !this.#args.multiple) {
      return;
    }
    const values = this._valueArray;
    if (values.length === 0 || this.isLockedValue(values.at(-1))) {
      return;
    }
    this.#emitChange(values.slice(0, -1), origin);
  }

  /**
   * Clears the selection down to its locked values, emitting them with `reason: "clear"`. Does
   * nothing when every held value is locked.
   */
  clear(origin?: SelectionOrigin): void {
    this.#onIntent(origin);
    if (this.#args.locked) {
      return;
    }
    if (origin && !this.hasValue) {
      return;
    }
    if (!this.#args.multiple) {
      this.#emitChange(null, origin, "clear");
      return;
    }
    const values = this._valueArray;
    const kept = values.filter((value) => this.isLockedValue(value));
    if (values.length > 0 && kept.length === values.length) {
      return;
    }
    this.#emitChange(kept, origin, "clear");
  }

  /**
   * Emits the next value plus the best-effort resolved record(s) for it. Controlled: the engine
   * never stores the value; the parent applies `nextValue` to `@value`.
   */
  #emitChange(
    rawNextValue: SelectValue,
    origin?: SelectionOrigin,
    reason?: "clear"
  ): void {
    // Coerce ids to their source record's native type up front, so the payload, the
    // change customization context, and the legacy bridge all emit one consistent,
    // single-typed value rather than a parent/URL-typed held id mixed with a freshly-picked
    // native one.
    const nextValue = this.#coerceValue(rawNextValue);
    const records = this.#recordsFor(nextValue);
    const payload = this.#args.multiple ? records : (records[0] ?? null);
    const context = {
      value: nextValue,
      records: payload,
      ...this.#getExtensionContext(),
    };

    // The selection-side-effect extension point: the default behavior emits the
    // controlled `onChange`; registered change middleware wraps it (and
    // may run `next()` to proceed or skip it).
    this.#runChange(() => {
      // Checked here as well as by each action, against the live value and locks: middleware
      // may run this step later, and programmatic writes reach it without a removal action.
      if (
        !this.#dropsLockedValue(nextValue) &&
        this.#beforeEmit(origin, nextValue) &&
        !this.#args.locked
      ) {
        this.#args.onChange?.(nextValue, payload, {
          origin,
          reason,
          config: context.config,
        });

        // Legacy extensions run only after the controlled change commits.
        this.#applyLegacyOnChange(nextValue, payload);
      }
    }, context);
  }

  #dropsLockedValue(nextValue: SelectValue): boolean {
    const locked = this.#lockedKeys;
    if (locked.size === 0) {
      return false;
    }
    const nextKeys = new Set(
      (makeArray(nextValue) as SelectId[]).map((value) =>
        this.#args.valueKey(value)
      )
    );
    return [...locked].some((key) => !nextKeys.has(key));
  }

  // Best-effort synchronous resolution of a value to its record(s), from the escape
  // hatch / cache / client list — never async (this feeds the `onChange` payload).
  #recordsFor(value: SelectValue): SelectRecord[] {
    const values: SelectId[] =
      value == null
        ? []
        : this.#args.multiple
          ? (makeArray(value) as SelectId[])
          : [value];
    return values
      .map((v) => this.#resolveOneSync(v))
      .filter((record): record is SelectRecord => record != null);
  }

  // Multi-select only: re-emit each id in its resolved source record's native type, so a held
  // parent/URL-typed id (a string `"5"`) and a freshly-picked native id (`3`) never leave as a
  // mixed-type array. An id that resolves to no known record passes through unchanged — its type is
  // unknowable — and order is preserved. Single-select already emits the native id, so its value
  // is returned untouched. Matching is by string form, so coercion never changes which option is
  // selected, only the emitted type.
  #coerceValue(value: SelectValue): SelectValue {
    if (!this.#args.multiple || value == null) {
      return value;
    }
    return (makeArray(value) as SelectId[]).map((id) => {
      const record = this.#resolveOneSync(id);
      return record ? this.#args.recordValue(record) : id;
    });
  }
}
