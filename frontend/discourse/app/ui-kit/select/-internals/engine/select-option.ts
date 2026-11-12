import { DEBUG } from "@glimmer/env";
import { assert } from "@ember/debug";
import type {
  SelectControl,
  SelectRecord,
} from "discourse/ui-kit/select/select-engine";

/** Where an option sits: pinned at the top while the list scrolls, or after every other option. */
export type SelectOptionPosition = "sticky" | "end";

/** Which side of the option a rule is drawn on. */
export type SelectOptionDivider = "before" | "after";

/** Bivariant in its record, so an option over a narrower record still fits a wider list. */
type SelectOptionAction<T> = {
  bivarianceHack(control: SelectControl, record: T): void;
}["bivarianceHack"];

/**
 * What an option does beyond standing for its record. Every setting is nullable, so a later
 * step can clear one with {@link SelectOption#with}.
 */
export interface SelectOptionSettings<T extends object = SelectRecord> {
  /** The option is listed but can't be picked. */
  disabled?: boolean | null;
  /** Secondary text drawn under the option's name and read as its description. */
  description?: string | null;
  /** Pins the option at the top, or holds it after every other option. */
  position?: SelectOptionPosition | null;
  /** Draws a rule between this option and its neighbour. */
  divider?: SelectOptionDivider | null;
  /**
   * Makes the option an action: picking it runs this with the select's control and the record
   * it was written for, and selects nothing.
   */
  onSelect?: SelectOptionAction<T> | null;
}

/**
 * The options the engine builds itself. No setting can produce one, so a caller's record is
 * never mistaken for the none option, a fallback or a group's boundary.
 */
export type SelectOptionKind =
  | "value"
  | "none"
  | "create"
  | "unresolved"
  | "text-header"
  | "text-footer"
  | "divider";

const SETTING_KEYS = new Set([
  "disabled",
  "description",
  "position",
  "divider",
  "onSelect",
]);
const POSITIONS = new Set(["sticky", "end"]);
const DIVIDERS = new Set(["before", "after"]);
const NO_SETTINGS = Object.freeze({});

/** Callbacks already bound to their record, so carrying one never rebinds it. */
const BOUND_ACTIONS = new WeakSet<object>();

/** One entry the select lists: the record it stands for and the settings it was given. */
class Option<T extends object> {
  static is(value: unknown): value is Option<object> {
    return typeof value === "object" && value !== null && #record in value;
  }

  static kindOf(option: Option<object>): SelectOptionKind {
    return option.#kind;
  }

  #record: T;
  #settings: Readonly<SelectOptionSettings<T>>;
  #kind: SelectOptionKind;

  constructor(
    record: T,
    settings: Readonly<SelectOptionSettings<T>>,
    kind: SelectOptionKind
  ) {
    this.#record = record;
    this.#settings = settings;
    this.#kind = kind;
    Object.freeze(this);
  }

  /** What was listed: the caller's own object, never a copy. */
  get record(): T {
    return this.#record;
  }

  /** The settings this option was given, for carrying them onto another record. */
  get settings(): Readonly<SelectOptionSettings<T>> {
    return this.#settings;
  }

  get disabled(): boolean {
    return !!this.#settings.disabled;
  }

  get description(): string | undefined {
    return this.#settings.description ?? undefined;
  }

  get position(): SelectOptionPosition | undefined {
    return this.#settings.position ?? undefined;
  }

  get divider(): SelectOptionDivider | undefined {
    return this.#settings.divider ?? undefined;
  }

  /** Whether picking it runs its `onSelect` instead of selecting a value. */
  get action(): boolean {
    return typeof this.#settings.onSelect === "function";
  }

  /** Whether this is the option that creates a value from the query. */
  get create(): boolean {
    return this.#kind === "create";
  }

  /** Whether this is the single-select option that clears the value. */
  get none(): boolean {
    return this.#kind === "none";
  }

  /**
   * The same record with settings merged.
   *
   * @param settings - `undefined` keeps a setting and `null` clears it.
   */
  with(settings: SelectOptionSettings<T> = {}): Option<T> {
    return new Option(
      this.#record,
      mergeSettings(this.#settings, settings, this.#record),
      this.#kind
    );
  }
}

/** What the select lists. Made with {@link selectOption}. */
export type SelectOption<T extends object = SelectRecord> = Option<T>;

/**
 * What a list accepts: a record as it is, or a record wrapped with settings. Any object is a
 * record, so model classes and interfaces fit without an index signature.
 */
export type SelectOptionLike<T extends object = object> = T | SelectOption<T>;

function validateSettings(settings: object): void {
  if (!DEBUG) {
    return;
  }
  for (const key of Object.keys(settings)) {
    assert(
      key === "sticky"
        ? 'DSelect: an option has no `sticky` setting; use `position: "sticky"`.'
        : `DSelect: \`${key}\` is not an option setting. The settings are disabled, description, position, divider and onSelect.`,
      SETTING_KEYS.has(key)
    );
  }
  const { position, divider, onSelect } = settings as SelectOptionSettings;
  assert(
    `DSelect: an option's \`position\` is "sticky" or "end", not "${String(position)}".`,
    position == null || POSITIONS.has(position)
  );
  assert(
    `DSelect: an option's \`divider\` is "before" or "after", not "${String(divider)}".`,
    divider == null || DIVIDERS.has(divider)
  );
  assert(
    "DSelect: an option's `onSelect` must be a function.",
    onSelect == null || typeof onSelect === "function"
  );
}

function bindAction<T extends object>(
  action: SelectOptionAction<T>,
  record: T
): SelectOptionAction<T> {
  if (BOUND_ACTIONS.has(action)) {
    return action;
  }
  const bound = (control: SelectControl) => action(control, record);
  BOUND_ACTIONS.add(bound);
  return bound;
}

function mergeSettings<T extends object>(
  current: Readonly<SelectOptionSettings<T>>,
  next: SelectOptionSettings<T>,
  record: T
): Readonly<SelectOptionSettings<T>> {
  validateSettings(next);
  const merged: Record<string, unknown> = { ...current };
  for (const [key, value] of Object.entries(next)) {
    if (value === undefined) {
      continue;
    }
    if (value === null) {
      delete merged[key];
      continue;
    }
    // Bound once, to the record it was written for, so a recipe carrying a caller's action onto
    // its own record still hands the caller's record back.
    merged[key] =
      key === "onSelect"
        ? bindAction(value as SelectOptionAction<T>, record)
        : value;
  }
  return Object.freeze(merged) as Readonly<SelectOptionSettings<T>>;
}

function build<T extends object>(
  record: T,
  settings: SelectOptionSettings<T> | undefined,
  kind: SelectOptionKind
): Option<T> {
  return new Option(
    record,
    settings ? mergeSettings(NO_SETTINGS, settings, record) : NO_SETTINGS,
    kind
  );
}

/**
 * Lists a record with settings. A wrapped record is still an option, the way `<option disabled>`
 * is still an option, and everything the select hands back is the record.
 *
 * @param entry - The record, or an option to give more settings.
 * @param settings - What the option does; `undefined` keeps a setting and `null` clears it.
 */
export function selectOption<T extends object>(
  entry: SelectOptionLike<T>,
  settings?: SelectOptionSettings<T>
): SelectOption<T> {
  if (Option.is(entry)) {
    return (entry as Option<T>).with(settings);
  }
  assert(
    `DSelect: an option stands for an object record, not ${entry === null ? "null" : typeof entry}.`,
    typeof entry === "object" && entry !== null
  );
  return build(entry as T, settings, "value");
}

/** Whether a list entry is an option rather than a bare record. */
export function isSelectOption(value: unknown): value is SelectOption<object> {
  return Option.is(value);
}

/** The record behind a list entry, wrapped or not. */
export function recordOf<T extends object>(entry: SelectOptionLike<T>): T {
  return Option.is(entry) ? (entry as Option<T>).record : (entry as T);
}

/**
 * The record behind an entry the engine holds. The engine reads records through their fields,
 * so it treats every object a caller listed as one. Internal to the select engine.
 */
export function entryRecord(entry: SelectOptionLike): SelectRecord {
  return recordOf(entry) as SelectRecord;
}

/** Which of the engine's own options this is; `"value"` for every caller's option. */
export function optionKind(option: SelectOption<object>): SelectOptionKind {
  return Option.kindOf(option);
}

/** Builds one of the engine's own options. Internal to the select engine. */
export function engineOption<T extends object>(
  kind: SelectOptionKind,
  record: T,
  settings?: SelectOptionSettings<T>
): SelectOption<T> {
  return build(record, settings, kind);
}

/**
 * Whether two options were given the same settings, compared entry by entry, so an option
 * rebuilt with equal settings reads as unchanged.
 */
export function sameSettings(
  a: Readonly<SelectOptionSettings<object>>,
  b: Readonly<SelectOptionSettings<object>>
): boolean {
  if (a === b) {
    return true;
  }
  const keys = Object.keys(a) as (keyof SelectOptionSettings)[];
  return (
    keys.length === Object.keys(b).length &&
    keys.every((key) => Object.hasOwn(b, key) && Object.is(a[key], b[key]))
  );
}
