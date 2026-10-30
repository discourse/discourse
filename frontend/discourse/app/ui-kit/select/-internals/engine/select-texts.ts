import { DEBUG } from "@glimmer/env";
import { assert, warn } from "@ember/debug";
import I18n, { i18n } from "discourse-i18n";

/** Values interpolated into a text, named after its default translation's placeholders. */
export type SelectTextValues = Readonly<Record<string, unknown>>;

/** What a text function or wrapper receives besides its values. */
export interface SelectTextContext {
  /** The select's recipe or family. */
  readonly kind: string | undefined;
  /** The select's call site. */
  readonly identifier: string | undefined;
  /** Whether the select holds several values. */
  readonly multiple: boolean;
  /**
   * Renders another text. For the text being evaluated, it returns the layer below; inside a
   * wrapper it returns the merged result the wrapper received.
   */
  text(key: string, values?: object): string;
}

/**
 * A customizable text: a translated string used as given, a translation key the engine fills
 * with the text's values, or a function of those values. `""` means "no text"; a function that
 * returns `null` or `undefined` hands back to the layer below.
 */
export type SelectText =
  | string
  | { readonly key: string }
  | ((
      values: SelectTextValues,
      context: SelectTextContext
    ) => string | null | undefined);

/** A recipe's final say over a text, applied once to the merged result of every layer. */
export type SelectTextWrapper = (
  final: string,
  values: SelectTextValues,
  context: SelectTextContext
) => string | null | undefined;

/** A layer of texts, keyed by text name; nullish entries leave the layer below in place. */
export type SelectTexts = Readonly<
  Record<string, SelectText | null | undefined>
>;

/** Default translation key of each engine text, under `d_select`. */
const LOCALE_KEYS = {
  addMorePlaceholder: "add_placeholder",
  searchPlaceholder: "search_placeholder",
  noResults: "no_results",
  ariaLabel: "label",
  labelWithValue: "label_with_value",
  labelWithCount: "label_with_count",
  footerLabel: "footer_label",
  clear: "clear",
  clearAll: "clear_all",
  selectionCleared: "selection_cleared",
  minChars: "min_chars",
  maximum: "max_reached",
  minimum: "min_not_reached",
  removeHint: "remove_hint",
  chipsLabel: "selected_items",
  stripLabel: "selected_items_list",
  removeItem: "remove_item",
  chipsHint: "chips_hint",
  selectedItemsHint: "selected_items_hint",
  selectedCount: "selected_count",
  updatingSelection: "updating_selection",
  itemSelected: "item_selected",
  itemAdded: "item_added",
  itemsAdded: "items_added",
  itemsNotAddedHeld: "items_not_added_held",
  itemsNotAddedLimit: "items_not_added_limit",
  bulkAddSummary: "bulk_add_summary",
  allAlreadySelected: "all_already_selected",
  itemRemoved: "item_removed",
  loadError: "load_error",
  retry: "retry",
  unresolvedValue: "unresolved_value",
  resultsCount: "results_count",
  resultsLoaded: "results_loaded",
  maxLoaded: "filter_to_narrow",
  stillLoading: "still_loading",
  loadingMore: "loading_more",
  loadingComplete: "loading_complete",
  createItem: "create_item",
  compactCount: "compact_count",
  moreChips: "more_chips",
  noneLabel: "none",
  loadingLabel: "loading",
} as const;

/** The engine's own text keys. */
export type SelectCoreTextKey = keyof typeof LOCALE_KEYS | "placeholder";

/** Every engine text's default; each points at an existing translation. */
export const DEFAULT_SELECT_TEXTS: Readonly<
  Record<SelectCoreTextKey, SelectText>
> = Object.freeze({
  placeholder: (_values: SelectTextValues, context: SelectTextContext) =>
    i18n(
      context.multiple ? "d_select.add_placeholder" : "d_select.placeholder"
    ),
  ...(Object.fromEntries(
    Object.entries(LOCALE_KEYS).map(([name, key]) => [
      name,
      Object.freeze({ key: `d_select.${key}` }),
    ])
  ) as Record<keyof typeof LOCALE_KEYS, SelectText>),
});

/** The texts that name a control or a group, so they can never be empty. */
export const REQUIRED_SELECT_TEXTS: ReadonlySet<string> = new Set([
  "ariaLabel",
  "clear",
  "clearAll",
  "retry",
  "removeItem",
  "chipsLabel",
  "stripLabel",
  "footerLabel",
  "labelWithValue",
  "labelWithCount",
  "unresolvedValue",
  "createItem",
  "removeHint",
  "loadError",
]);

/**
 * Text keys reserved for the recipes. A `forAll` customization may set them for every select,
 * so selects whose kind lacks one of them don't warn about it.
 */
export const RECIPE_TEXT_KEYS: ReadonlySet<string> = new Set([
  "readOnlyDescription",
  "familyFooter",
  "removeFilter",
  "noSubcategories",
  "requiredTagGroup",
  "requiredTagGroupRemaining",
  "minimumPlaceholder",
  "minimumRemaining",
  "addMoreTags",
  "tagCountBadge",
  "tagCount",
  "noTags",
  "filterForMore",
]);

/** Whether a key is one of the engine's own texts. */
export function isCoreTextKey(key: string): key is SelectCoreTextKey {
  return Object.hasOwn(DEFAULT_SELECT_TEXTS, key);
}

/** One layer of the stack, named for error messages. */
export interface SelectTextLayer {
  readonly source: string;
  readonly texts: SelectTexts;
}

/** Notices already given for one select, so each warns or reports once. */
export class SelectTextNotices {
  #given = new Set<string>();
  #reported = new Set<string>();

  /** Warns once per id and key for this select. */
  warn(message: string, id: string, key: string): void {
    if (!DEBUG) {
      return;
    }
    const token = `${id}:${key}`;
    if (this.#given.has(token)) {
      return;
    }
    this.#given.add(token);
    warn(message, false, { id });
  }

  /** Whether an invalid text is this select's first report for its key. */
  firstReport(key: string): boolean {
    if (this.#reported.has(key)) {
      return false;
    }
    this.#reported.add(key);
    return true;
  }
}

/** `forAll` customizations apply to every select, so their unknown keys warn once overall. */
let forAllNotices = new SelectTextNotices();

/** The notices shared by every select's `forAll` customizations. */
export function forAllTextNotices(): SelectTextNotices {
  return forAllNotices;
}

/** Forgets the shared notices, so each test sees its own warnings. */
export function resetSelectTextNotices(): void {
  forAllNotices = new SelectTextNotices();
}

/** What a resolver needs about its select. */
export interface SelectTextResolverOptions {
  layers: readonly SelectTextLayer[];
  wrappers?: Readonly<Record<string, SelectTextWrapper | undefined>>;
  kind: string | undefined;
  identifier: string | undefined;
  multiple: boolean;
  notices: SelectTextNotices;
  /** Texts that can't be empty; defaults to {@link REQUIRED_SELECT_TEXTS}. */
  required?: ReadonlySet<string>;
  /**
   * Development only: receives invalid-text reports instead of the assertion, so tests can reach
   * the fallback production uses. Production builds never read it.
   */
  report?: (message: string, error?: unknown) => void;
}

const RESOLVER = Symbol("select-texts");
const MISSING_VALUE = /\[missing %\{[^}]+\} value\]/;
const TRANSLATION_KEY = /^[a-z0-9_]+(\.[a-z0-9_]+)+$/;

/** Reports an invalid text as a client error; the text then falls back. */
function reportInvalid(message: string, error?: unknown): void {
  document.dispatchEvent(
    new CustomEvent("discourse-error", {
      detail: {
        messageKey: "broken_transformer_alert",
        error: error ?? new Error(message),
      },
    })
  );
}

/** Renders texts for one options snapshot: its layers, wrappers and select state. */
export class SelectTextResolver {
  #options: SelectTextResolverOptions;
  #evaluating = new Set<string>();

  constructor(options: SelectTextResolverOptions) {
    this.#options = options;
  }

  /** Renders a text with its wrapper: what is drawn or spoken. */
  render(key: string, values: object = {}): string {
    const merged = this.#merged(key, values);
    const wrapper = this.#options.wrappers?.[key];
    if (!wrapper) {
      return merged;
    }
    const context = this.#context(key, () => merged);
    const result = this.#call(
      key,
      "wrapper",
      () => wrapper(merged, values as SelectTextValues, context),
      `the wrapper of text "${key}"`
    );
    return this.#checked(key, result ?? merged, merged, values);
  }

  /** Whether a layer above the engine default sets a non-blank text. */
  explicit(key: string): boolean {
    const text = this.#from(key, {}, this.#options.layers.length - 1, false);
    return !!text?.trim();
  }

  /** Renders a text from every layer, without its wrapper. */
  #merged(key: string, values: object = {}): string {
    return (
      this.#from(key, values, this.#options.layers.length - 1) ??
      this.#fromDefault(key, values) ??
      ""
    );
  }

  /**
   * Renders a text from `index` down to the engine default, or `undefined` when unset. An empty
   * required text is reported and skipped, so the layer below it shows.
   */
  #from(
    key: string,
    values: object,
    index: number,
    report = true
  ): string | undefined {
    for (let layer = index; layer >= 0; layer--) {
      const entry = this.#options.layers[layer]!.texts[key];
      if (entry === null || entry === undefined) {
        continue;
      }
      const result = this.#evaluate(
        key,
        values,
        entry,
        `layer ${layer}`,
        (passed = values) =>
          (layer > 0
            ? this.#from(key, passed, layer - 1, report)
            : undefined) ??
          this.#fromDefault(key, passed) ??
          ""
      );
      if (result === undefined) {
        continue;
      }
      if (this.#isRequired(key) && !result.trim()) {
        if (report) {
          this.#invalid(key, this.#emptyMessage(key));
        }
        continue;
      }
      return result;
    }
    return undefined;
  }

  /** Renders the engine default, or `undefined` for a key with none. */
  #fromDefault(key: string, values: object): string | undefined {
    if (!isCoreTextKey(key)) {
      return undefined;
    }
    return this.#evaluate(
      key,
      values,
      DEFAULT_SELECT_TEXTS[key],
      "default",
      () => ""
    );
  }

  /** Renders one entry; `undefined` defers to the layer below. */
  #evaluate(
    key: string,
    values: object,
    entry: unknown,
    layer: string,
    below: (values?: object) => string
  ): string | undefined {
    if (typeof entry === "string") {
      if (entry.includes("%{")) {
        this.#invalid(
          key,
          `DSelect: text "${key}" contains an unexpanded "%{" placeholder; pass { key } to translate it`
        );
        return undefined;
      }
      if (TRANSLATION_KEY.test(entry) && I18n.lookup(entry) !== undefined) {
        this.#options.notices.warn(
          `DSelect: text "${key}" is the translation key "${entry}" given as a string; it is shown as is. Pass { key: "${entry}" } to translate it.`,
          "discourse.d-select.texts-translation-key-as-string",
          key
        );
      }
      return entry;
    }
    if (typeof entry === "function") {
      const context = this.#context(key, below);
      const result = this.#call(
        key,
        layer,
        () =>
          (entry as (v: object, c: SelectTextContext) => unknown)(
            values,
            context
          ),
        `text "${key}"`
      );
      return result ?? undefined;
    }
    if (
      entry &&
      typeof entry === "object" &&
      !Array.isArray(entry) &&
      typeof (entry as { key?: unknown }).key === "string"
    ) {
      return this.#translate(key, (entry as { key: string }).key, values);
    }
    this.#invalid(
      key,
      `DSelect: text "${key}" must be a string, { key } or a function, got ${Array.isArray(entry) ? "an array" : typeof entry}`
    );
    return undefined;
  }

  /** Translates a `{ key }` entry, catching a message that needs a value the text doesn't pass. */
  #translate(key: string, locale: string, values: object): string | undefined {
    if (I18n.lookup(locale) === undefined) {
      this.#options.notices.warn(
        `DSelect: text "${key}" uses the translation key "${locale}", which isn't in the locale`,
        "discourse.d-select.texts-missing-translation",
        key
      );
    }
    let result: string;
    try {
      result = i18n(locale, values);
    } catch (error) {
      this.#invalid(
        key,
        `DSelect: text "${key}" uses "${locale}", which needs a value the text doesn't pass (${(error as Error).message})`,
        error
      );
      return undefined;
    }
    if (MISSING_VALUE.test(result)) {
      this.#invalid(
        key,
        `DSelect: text "${key}" uses "${locale}", which needs a value the text doesn't pass`
      );
      return undefined;
    }
    return result;
  }

  /** Calls a text function or wrapper, guarding cycles and invalid results. */
  #call(
    key: string,
    layer: string,
    callback: () => unknown,
    description: string
  ): string | null | undefined {
    const token = `${key}@${layer}`;
    if (this.#evaluating.has(token)) {
      this.#invalid(
        key,
        `DSelect: ${description} reads itself through another text`
      );
      return undefined;
    }
    this.#evaluating.add(token);
    let result: unknown;
    try {
      result = callback();
    } catch (error) {
      if (
        error instanceof Error &&
        /^Assertion Failed/.test(error.message) &&
        /^Assertion Failed: DSelect: /.test(error.message)
      ) {
        throw error;
      }
      this.#invalid(
        key,
        `DSelect: ${description} threw: ${(error as Error)?.message ?? error}`,
        error
      );
      return undefined;
    } finally {
      this.#evaluating.delete(token);
    }
    if (result === null || result === undefined) {
      return undefined;
    }
    if (typeof result !== "string") {
      this.#invalid(
        key,
        `DSelect: ${description} must return a string, null or undefined, got ${typeof result}`
      );
      return undefined;
    }
    if (result.includes("%{")) {
      this.#invalid(
        key,
        `DSelect: ${description} returned an unexpanded "%{" placeholder`
      );
      return undefined;
    }
    return result;
  }

  /** Reports a wrapper that empties a required text, which then shows the text it wrapped. */
  #checked(key: string, text: string, merged: string, values: object): string {
    if (this.#isRequired(key) && !text.trim()) {
      this.#invalid(key, this.#emptyMessage(key));
      return merged.trim() ? merged : (this.#fromDefault(key, values) ?? text);
    }
    return text;
  }

  #isRequired(key: string): boolean {
    return (this.#options.required ?? REQUIRED_SELECT_TEXTS).has(key);
  }

  #emptyMessage(key: string): string {
    return `DSelect: the "${key}" text can't be empty, because it names a control or a group`;
  }

  /**
   * Asserts in development. Otherwise reports once per key for this select, and the caller falls
   * back. A test-supplied `report` replaces the assertion, so the fallback can be tested.
   */
  #invalid(key: string, message: string, error?: unknown): void {
    const report = DEBUG && this.#options.report;
    if (DEBUG && !report) {
      assert(message, false);
    }
    if (this.#options.notices.firstReport(key)) {
      (report || reportInvalid)(message, error);
    }
  }

  #context(key: string, own: (values?: object) => string): SelectTextContext {
    return {
      kind: this.#options.kind,
      identifier: this.#options.identifier,
      multiple: this.#options.multiple,
      text: (other: string, values?: object) =>
        other === key ? own(values) : this.#merged(other, values),
    };
  }
}

/** Attaches a resolver to a snapshot before it's frozen, out of sight of enumeration. */
export function attachSelectTextResolver(
  snapshot: object,
  resolver: SelectTextResolver
): void {
  Object.defineProperty(snapshot, RESOLVER, { value: resolver });
}

/** The resolver a snapshot carries, if any. */
export function selectTextResolver(
  options: object | null | undefined
): SelectTextResolver | undefined {
  return options
    ? (options as Record<symbol, SelectTextResolver | undefined>)[RESOLVER]
    : undefined;
}

let defaultResolver: SelectTextResolver | undefined;

/**
 * Renders a text against a resolved options snapshot, as recipes receive it in `specialItems`,
 * group builders, blocks and customization callbacks. Returns `""` when the text is "no text".
 */
export function renderSelectText(
  options: object,
  key: string,
  values: object = {}
): string {
  let resolver = selectTextResolver(options);
  if (!resolver) {
    if (DEBUG) {
      warn(
        "DSelect: renderSelectText needs a resolved options snapshot; using the engine defaults",
        false,
        { id: "discourse.d-select.texts-no-snapshot" }
      );
    }
    defaultResolver ??= new SelectTextResolver({
      layers: [],
      kind: undefined,
      identifier: undefined,
      multiple: false,
      notices: new SelectTextNotices(),
    });
    resolver = defaultResolver;
  }
  return resolver.render(key, values);
}
