import { DEBUG } from "@glimmer/env";
import { assert, warn } from "@ember/debug";
import {
  applyMutableValueTransformer,
  withTransformerErrorHandling,
} from "discourse/lib/transformer";
import {
  attachSelectTextResolver,
  DEFAULT_SELECT_TEXTS,
  forAllTextNotices,
  isCoreTextKey,
  RECIPE_TEXT_KEYS,
  REQUIRED_SELECT_TEXTS,
  SelectTextNotices,
  SelectTextResolver,
  selectTextResolver,
  type SelectTexts,
  type SelectTextWrapper,
} from "discourse/ui-kit/select/-internals/engine/select-texts";
import type {
  SelectControl,
  SelectEngineOptions,
  SelectItem,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** Names captured when a select is constructed. */
export interface SelectNames {
  /** The select's recipe or family. */
  kind: string | undefined;
  /** The select's call site, also used by its menu. */
  identifier: string | undefined;
}

/** Live data shared by the customization points. */
export interface SelectCustomizationContext extends SelectNames {
  /** Data published by the recipe. */
  kindContext: object;
  /** Data published by the call site. */
  instanceContext: object;
}

/** What a content step receives. */
export interface SelectContentContext extends SelectResolvedContext {
  /** The current query. */
  filter: string;
  /** The normalized controlled value. */
  value: SelectValue;
  /** The live select handle; only read it while building content. */
  control: SelectControl;
}

/** Core presentation values that customizations may override. */
export interface SelectPresentationOptions {
  /** The caret glyph, optionally chosen separately for each menu state. */
  caretIcon?:
    | string
    | Readonly<{
        /** The glyph while the menu is open. */
        open?: string;
        /** The glyph while the menu is closed. */
        closed?: string;
      }>;
  /** Suppresses trigger text when `texts.ariaLabel` supplies its accessible name. */
  iconOnly?: boolean;
  /**
   * Every text the select draws or speaks, merged per entry over the layers below.
   *
   * @see SelectText
   */
  texts?: SelectTexts;
  /** The accessible name of the trigger and listbox; it is never drawn. */
  ariaLabel?: string;
  /** Text shown when nothing is selected. */
  placeholder?: string;
  /** Text shown in an empty panel filter. */
  searchPlaceholder?: string;
  /** A decorative trailing icon in a search field that is not the trigger. */
  searchIcon?: string;
  /** Shows a status line, with a spinner, above the loading skeleton; off by default. */
  loadingStatus?: boolean;
  /** Turns the loading status line on, labeled with this text. */
  loadingLabel?: string;
  /** A decorative leading trigger icon. */
  icon?: string;
  /** Whether the trigger shows its caret. */
  showCaret?: boolean;
  /** Whether a selection can offer a clear control. */
  clearable?: boolean;
  /** Adds a single-select "none" row that clears the value; off by default. */
  noneRow?: boolean;
  /** Turns the single-select none row on, labeled with this text; empty leaves it off. */
  noneLabel?: string;
  /** An additive lock: a later customization cannot remove it. */
  disabled?: boolean;
}

/** The call site's presentation arguments, read before customizations. */
export interface SelectPresentationArgs extends SelectPresentationOptions {
  /** Label for an empty result set. */
  noResultsLabel?: string;
  /** Id of the caller's visible caption, which names the control instead of `texts.ariaLabel`. */
  ariaLabelledBy?: string;
}

/** Core and declared recipe values, resolved together into an immutable snapshot. */
export type SelectResolvedOptions = Readonly<
  SelectPresentationOptions & Record<string, unknown>
>;

/** Runtime customization data after options resolution. */
export interface SelectResolvedContext extends SelectCustomizationContext {
  /** The resolved core and recipe values at invocation time. */
  options: SelectResolvedOptions;
}

/** Core keys reserved from recipe declarations, including keys with no base value. */
const CORE_OPTION_KEYS = new Set<keyof SelectPresentationOptions>([
  "caretIcon",
  "iconOnly",
  "texts",
  "ariaLabel",
  "placeholder",
  "searchPlaceholder",
  "searchIcon",
  "loadingStatus",
  "loadingLabel",
  "icon",
  "showCaret",
  "clearable",
  "noneRow",
  "noneLabel",
  "disabled",
]);

/** Old arguments and option keys that carry a text, and the text each one sets. */
const LEGACY_TEXTS: Readonly<Record<string, string>> = {
  ariaLabel: "ariaLabel",
  placeholder: "placeholder",
  searchPlaceholder: "searchPlaceholder",
  noResultsLabel: "noResults",
  noneLabel: "noneLabel",
  loadingLabel: "loadingLabel",
};

/** Texts a wrapper can never change: the required texts, and the none row's and loading status's. */
const UNWRAPPABLE_TEXTS = new Set([
  ...REQUIRED_SELECT_TEXTS,
  "noneLabel",
  "loadingLabel",
]);

/** The text inputs of one resolution, read live by the engine. */
export interface SelectTextInputs {
  /** The recipe's `@kindTexts`. */
  kindTexts: SelectTexts | undefined;
  /** The call site's `@texts`. */
  texts: SelectTexts | undefined;
  /** The call site's old text arguments, by argument name. */
  legacy: Readonly<Record<string, unknown>>;
  /** The recipe's `@kindTextWrappers`. */
  wrappers: Readonly<Record<string, SelectTextWrapper | undefined>> | undefined;
  /** Whether the select holds several values. */
  multiple: boolean;
  /** Whether a visible caption names the control, so `ariaLabel` may be empty. */
  labelledBy: boolean;
}

/** Options callbacks read upstream state only, avoiding selection and presentation cycles. */
export interface SelectOptionsContext extends SelectCustomizationContext {
  /** The normalized controlled value. */
  value: SelectValue;
  /** The live select handle; only read it while resolving options. */
  control: SelectControl;
}

/** Presentation starts fresh for every option row evaluation. */
export interface SelectRowPresentation {
  /** Classes appended to the core classes; falsy entries are ignored. */
  classes: (string | false | null | undefined | 0)[];
  /** An explicit tooltip; an item's own title is never used implicitly. */
  title: string | undefined;
}

/** State of the option row being presented. */
export interface SelectRowContext extends SelectResolvedContext {
  /** The raw item behind the row. */
  item: SelectItem;
  /** Whether the item is held. */
  selected: boolean;
  /** Whether activation is disabled. */
  disabled: boolean;
}

/** What a load step receives; it runs once per query. */
export interface SelectLoadContext extends SelectResolvedContext {
  /** The query's shallow snapshot of the caller's `@loadContext`. */
  loadContext: Readonly<Record<string, unknown>>;
  /** The query being loaded. */
  filter: string;
  /** The live select handle. */
  control: SelectControl;
}

/** The proposed selection, before the controlled consumer is called. */
export interface SelectChangeContext extends SelectResolvedContext {
  /** The proposed value, coerced to the source's id types. */
  value: SelectValue;
  /** Best-effort resolved items, with the select's single/multiple arity. */
  items: SelectItem | SelectItem[] | null;
  /** The live select handle, shared with content callbacks. */
  control: SelectControl;
}

/** A content step replaces the list passed to the following step. */
type Content = (
  items: SelectItem[],
  context: SelectContentContext
) => SelectItem[];
/** A row step mutates presentation; its return value is ignored. */
type Row = (row: SelectRowPresentation, context: SelectRowContext) => void;
/** An options step returns a partial over an immutable snapshot of the values so far. */
type Options = (
  current: SelectResolvedOptions,
  context: SelectOptionsContext
) => (Partial<SelectPresentationOptions> & Record<string, unknown>) | void;
/** The loader a load step receives and returns. */
type Loader = NonNullable<SelectEngineOptions["load"]>;
/** A load step wraps or replaces the previous loader. */
type Load = (load: Loader, context: SelectLoadContext) => Loader;
/** A continuation can be held, vetoed, or awaited, but only runs once. */
type Next = () => void | Promise<void>;
/** Change middleware: call `next` to continue, or skip it to veto. */
type Change = (
  next: Next,
  context: SelectChangeContext
) => void | Promise<void>;

/** Declare-only builder, valid only during its synchronous setup. */
export interface SelectCustomizationSpec {
  /** Appends a content step. */
  content(callback: Content): void;
  /** Appends a row presentation step. */
  row(callback: Row): void;
  /** Appends a step resolving core and declared recipe options. */
  options(callback: Options): void;
  /** Appends a loader step. */
  load(callback: Load): void;
  /** Appends change middleware. */
  change(callback: Change): void;
}

/** A setup has per-select closure state and may only register synchronous declarations. */
type Setup = (spec: SelectCustomizationSpec, names: SelectNames) => unknown;

/** The mutable value passed to the single select transformer. */
export interface SelectCustomizationRegistry {
  /** Registers a setup for every select. */
  forAll(setup: Setup): void;
  /** Registers a setup for an exact kind. */
  forKind(kind: string, setup: Setup): void;
  /** Registers a setup for an exact call-site identifier. */
  forIdentifier(identifier: string, setup: Setup): void;
}

/** Isolated declarations from one setup; committed only when the setup succeeds. */
class Declarations {
  /** Content steps, in declaration order. */
  content: Content[] = [];

  /** Row steps, in declaration order. */
  row: Row[] = [];

  /** Options steps, in declaration order. */
  options: Options[] = [];

  /** The tier of each options step: 0 for `forAll`, 1 for `forKind`, 2 for `forIdentifier`. */
  optionsTiers: number[] = [];

  /** Loader steps, in declaration order. */
  load: Load[] = [];

  /** Change middleware, in declaration order. */
  change: Change[] = [];
}

/** Collects sealed, per-select declarations and isolates each runtime invocation. */
export default class SelectCustomizations {
  /** Only declarations from successful setups reach the runtime points. */
  #steps = new Declarations();

  /** Recipe schema is captured once; base values are read live during resolution. */
  #kindOptionKeys: string[];

  /** Text keys the recipe declares, captured once like its option keys. */
  #kindTextKeys: Set<string>;

  /** Texts the recipe wraps, captured once; the wrappers themselves are read live. */
  #wrapperKeys: string[];

  #names: SelectNames;

  /** Each text notice is given once per select, however often its options resolve again. */
  #notices = new SelectTextNotices();

  /** Collects all registrations before running matching setups in tier order. */
  constructor(
    names: SelectNames,
    kindOptions?: Record<string, unknown>,
    textSchema: {
      kindTexts?: SelectTexts;
      kindTextWrappers?: Readonly<Record<string, unknown>>;
    } = {}
  ) {
    assert(
      "DSelect: @kindOptions requires @kind",
      !kindOptions || !!names.kind
    );
    assert(
      "DSelect: @kindTexts requires @kind",
      !textSchema.kindTexts || !!names.kind
    );
    assert(
      "DSelect: @kindTextWrappers requires @kind",
      !textSchema.kindTextWrappers || !!names.kind
    );
    this.#names = names;
    this.#kindOptionKeys = Object.keys(kindOptions ?? {});
    for (const key of this.#kindOptionKeys) {
      assert(
        `DSelect: @kindOptions key "${key}" collides with a core option`,
        !CORE_OPTION_KEYS.has(key as keyof SelectPresentationOptions)
      );
    }
    this.#kindTextKeys = new Set(
      Object.keys(textSchema.kindTexts ?? {}).filter(
        (key) => !isCoreTextKey(key)
      )
    );
    for (const key of this.#kindTextKeys) {
      const collision = Object.keys(DEFAULT_SELECT_TEXTS).find(
        (core) => core.toLowerCase() === key.toLowerCase()
      );
      assert(
        `DSelect: @kindTexts key "${key}" collides with the core text "${collision}"; text keys are case-sensitive`,
        !collision
      );
    }
    this.#wrapperKeys = Object.keys(textSchema.kindTextWrappers ?? {});
    for (const key of this.#wrapperKeys) {
      assert(
        `DSelect: @kindTextWrappers can't wrap "${key}", a text that must never be empty`,
        !UNWRAPPABLE_TEXTS.has(key)
      );
    }
    const tiers: Setup[][] = [[], [], []];
    let sealed = false;
    const register = (tier: number, setup: Setup, target?: string): void => {
      if (sealed) {
        throw new Error("Select customization registry is sealed");
      }
      if (tier > 0 && (typeof target !== "string" || !target.length)) {
        throw new Error(
          "Select customization target must be a non-empty string"
        );
      }
      if (
        tier === 0 ||
        (tier === 1 && target === names.kind) ||
        (tier === 2 && target === names.identifier)
      ) {
        tiers[tier]!.push(setup);
      }
    };
    const registry: SelectCustomizationRegistry = {
      forAll: (setup) => register(0, setup),
      forKind: (kind, setup) => register(1, setup, kind),
      forIdentifier: (identifier, setup) => register(2, setup, identifier),
    };
    try {
      applyMutableValueTransformer("select-customizations", registry);
    } finally {
      sealed = true;
    }

    tiers.forEach((setups, tier) => {
      for (const setup of setups) {
        this.#setup(setup, names, tier);
      }
    });
  }

  /** Chains valid arrays, retaining the previous list when a step fails. */
  applyContent(
    items: SelectItem[],
    context: SelectContentContext
  ): SelectItem[] {
    for (const step of this.#steps.content) {
      const previous = items;
      items =
        withTransformerErrorHandling(() => {
          const result = step(previous, context);
          assert(
            "DSelect: content customization must return an array",
            Array.isArray(result)
          );
          return Array.isArray(result) ? result : previous;
        }) ?? items;
    }
    return items;
  }

  /** Keeps mutations made before a row step fails, then continues the remaining steps. */
  applyRow(context: SelectRowContext): SelectRowPresentation {
    const row: SelectRowPresentation = { classes: [], title: undefined };
    for (const step of this.#steps.row) {
      withTransformerErrorHandling(() => step(row, context));
    }
    return row;
  }

  /** Chains valid loader functions, retaining the previous loader on failure. */
  applyLoad(load: Loader, context: SelectLoadContext): Loader {
    for (const step of this.#steps.load) {
      const previous = load;
      load =
        withTransformerErrorHandling(() => {
          const result = step(previous, context);
          assert(
            "DSelect: load customization must return a function",
            typeof result === "function"
          );
          return typeof result === "function" ? result : previous;
        }) ?? load;
    }
    return load;
  }

  /**
   * Resolves core and recipe keys in tier order, keeping snapshots immutable and locks additive.
   * Texts merge per entry instead: each step adds a layer, and every snapshot carries a resolver
   * over the layers it has seen.
   */
  resolveOptions(
    base: SelectPresentationOptions,
    kindOptions: Record<string, unknown> | undefined,
    context: SelectOptionsContext,
    textInputs: SelectTextInputs
  ): SelectResolvedOptions {
    const declared: SelectPresentationOptions & Record<string, unknown> = {
      ...base,
      ...Object.fromEntries(
        this.#kindOptionKeys.map((key) => [
          key,
          kindOptions?.[key] ?? undefined,
        ])
      ),
      texts: undefined,
    };
    const wrappers = Object.fromEntries(
      this.#wrapperKeys.map((key) => [key, textInputs.wrappers?.[key]])
    );
    // Old arguments and option keys sit in their own layer just below their step's `texts`, so a
    // nullish entry there still leaves them in place and `text(ownKey)` reaches them.
    const layers: Array<Record<string, unknown>> = [
      this.#kindTextLayer(textInputs.kindTexts),
      this.#legacyLayer(textInputs.legacy, "argument"),
      this.#textLayer(textInputs.texts, "@texts"),
    ];
    let current = this.#optionsSnapshot(declared, layers, wrappers, textInputs);
    this.#steps.options.forEach((step, index) => {
      const previous = current;
      const partial = withTransformerErrorHandling(
        () => step(previous, context),
        () => undefined
      );
      if (!partial || typeof partial !== "object" || Array.isArray(partial)) {
        return;
      }
      const next = { ...current };
      const legacy: Record<string, unknown> = {};
      for (const key of Object.keys(partial)) {
        if (key === "texts") {
          continue;
        }
        if (!Object.hasOwn(declared, key)) {
          if (DEBUG) {
            warn(`DSelect: unknown options customization key "${key}"`, false, {
              id: "discourse.d-select.unknown-option",
            });
          }
          continue;
        }
        if (Object.hasOwn(LEGACY_TEXTS, key)) {
          legacy[key] = partial[key];
        }
        Object.assign(next, {
          [key]:
            key === "disabled"
              ? !!current.disabled || !!partial.disabled
              : partial[key],
        });
      }
      layers.push(
        this.#legacyLayer(legacy, "option"),
        this.#textLayer(
          partial.texts,
          "a customization",
          this.#steps.optionsTiers[index] === 0
        )
      );
      current = this.#optionsSnapshot(next, layers, wrappers, textInputs);
    });
    const noneRow = !!(current.noneRow || current.noneLabel);
    const loadingStatus = !!(current.loadingStatus || current.loadingLabel);
    let iconOnly = current.iconOnly;
    if (iconOnly && !selectTextResolver(current)!.explicit("ariaLabel")) {
      if (DEBUG) {
        warn(
          "DSelect: iconOnly requires an ariaLabel text and is ignored without one",
          false,
          {
            id: "discourse.d-select.icon-only-without-label",
          }
        );
      }
      iconOnly = false;
    }
    if (
      noneRow !== current.noneRow ||
      loadingStatus !== current.loadingStatus ||
      iconOnly !== current.iconOnly
    ) {
      current = this.#optionsSnapshot(
        { ...current, noneRow, loadingStatus, iconOnly },
        layers,
        wrappers,
        textInputs
      );
    }
    return current;
  }

  /** Runs once-only continuations without reporting errors originating downstream. */
  runChange(
    defaultStep: Next,
    context: SelectChangeContext
  ): void | Promise<void> {
    const run = (index: number): void | Promise<void> => {
      const step = this.#steps.change[index];
      if (!step) {
        return defaultStep();
      }
      let called = false;
      const downstreamErrors = new Set<unknown>();
      const forwardError = (error: unknown): never => {
        downstreamErrors.add(error);
        throw error;
      };
      const next: Next = () => {
        if (called) {
          return;
        }
        called = true;
        try {
          const result = run(index + 1);
          return result && Promise.resolve(result).catch(forwardError);
        } catch (error) {
          return forwardError(error);
        }
      };
      const onError = (error: unknown): void | Promise<void> => {
        if (downstreamErrors.has(error)) {
          throw error;
        }
        return withTransformerErrorHandling(() => {
          throw error;
        }, next);
      };
      try {
        const result = step(next, context);
        return result && Promise.resolve(result).catch(onError);
      } catch (error) {
        return onError(error);
      }
    };
    return run(0);
  }

  /**
   * Copies nested caret state and the merged texts, so freezing a snapshot never freezes
   * caller-owned data, then attaches a resolver over the text layers seen so far.
   */
  #optionsSnapshot(
    options: SelectPresentationOptions & Record<string, unknown>,
    layers: ReadonlyArray<Record<string, unknown>>,
    wrappers: Readonly<Record<string, unknown>>,
    textInputs: SelectTextInputs
  ): SelectResolvedOptions {
    const texts: Record<string, unknown> = {};
    for (const layer of layers) {
      for (const [key, entry] of Object.entries(layer)) {
        if (entry !== null && entry !== undefined) {
          texts[key] = entry;
        }
      }
    }
    const snapshot = {
      ...options,
      texts: Object.freeze(texts) as SelectTexts,
      caretIcon:
        typeof options.caretIcon === "object" && options.caretIcon !== null
          ? Object.freeze({ ...options.caretIcon })
          : options.caretIcon,
    };
    const required = new Set(REQUIRED_SELECT_TEXTS);
    if (textInputs.labelledBy) {
      required.delete("ariaLabel");
    }
    if (options.noneRow || options.noneLabel) {
      required.add("noneLabel");
    }
    if (options.loadingStatus || options.loadingLabel) {
      required.add("loadingLabel");
    }
    attachSelectTextResolver(
      snapshot,
      new SelectTextResolver({
        layers: layers.map((layer, index) => ({
          source: `layer ${index}`,
          texts: Object.freeze({ ...layer }) as SelectTexts,
        })),
        wrappers: wrappers as Record<string, SelectTextWrapper | undefined>,
        kind: this.#names.kind,
        identifier: this.#names.identifier,
        multiple: textInputs.multiple,
        notices: this.#notices,
        required,
      })
    );
    return Object.freeze(snapshot);
  }

  /** The recipe's layer: its declared keys and core keys, without warnings. */
  #kindTextLayer(texts: SelectTexts | undefined): Record<string, unknown> {
    if (!texts || typeof texts !== "object") {
      return {};
    }
    return Object.fromEntries(
      Object.entries(texts).filter(([key]) => this.#isKnownText(key))
    );
  }

  /** A call-site or customization layer; unknown keys warn once and are left out. */
  #textLayer(
    texts: unknown,
    source: string,
    forAll = false
  ): Record<string, unknown> {
    if (!texts || typeof texts !== "object" || Array.isArray(texts)) {
      return {};
    }
    const layer: Record<string, unknown> = {};
    for (const [key, entry] of Object.entries(texts)) {
      if (this.#isKnownText(key)) {
        layer[key] = entry;
      } else if (!(forAll && RECIPE_TEXT_KEYS.has(key))) {
        (forAll ? forAllTextNotices() : this.#notices).warn(
          `DSelect: ${source} sets the unknown text "${key}". Known texts are the engine's and those of kind "${this.#names.kind ?? "(none)"}": ${[...Object.keys(DEFAULT_SELECT_TEXTS), ...this.#kindTextKeys].join(", ")}. Old names: noResultsLabel is noResults, minimumLabel is minimum, maximumLabel is maximum.`,
          "discourse.d-select.texts-unknown-key",
          key
        );
      }
    }
    return layer;
  }

  /**
   * Maps old text arguments or option keys onto their texts. `""` removes the prompt for
   * `searchPlaceholder`; for any other argument it shows the layer below, and for an option key
   * it shows the engine default, so the option still overrides the argument.
   */
  #legacyLayer(
    legacy: Readonly<Record<string, unknown>>,
    source: "argument" | "option"
  ): Record<string, unknown> {
    const layer: Record<string, unknown> = {};
    for (const [name, key] of Object.entries(LEGACY_TEXTS)) {
      const value = legacy[name];
      if (value === undefined) {
        continue;
      }
      this.#notices.warn(
        source === "argument"
          ? `DSelect: @${name} is replaced by @texts={{hash ${key}=…}}`
          : `DSelect: the "${name}" option is replaced by { texts: { ${key}: … } }`,
        "discourse.d-select.texts-legacy",
        name
      );
      layer[key] =
        value === "" ? this.#emptyLegacyText(name, key, source) : value;
    }
    return layer;
  }

  #emptyLegacyText(
    name: string,
    key: string,
    source: "argument" | "option"
  ): unknown {
    if (name === "searchPlaceholder") {
      return "";
    }
    return source === "option"
      ? DEFAULT_SELECT_TEXTS[key as keyof typeof DEFAULT_SELECT_TEXTS]
      : undefined;
  }

  #isKnownText(key: string): boolean {
    return isCoreTextKey(key) || this.#kindTextKeys.has(key);
  }

  /** Seals even failed setups and discards every declaration they made. */
  #setup(setup: Setup, names: SelectNames, tier: number): void {
    const pending = new Declarations();
    let sealed = false;
    const append = <T>(list: T[], callback: T): void => {
      if (sealed) {
        throw new Error("Select customization spec is sealed");
      }
      if (typeof callback !== "function") {
        throw new Error("Select customization callback must be a function");
      }
      list.push(callback);
    };
    const spec = new Proxy<SelectCustomizationSpec>(
      {
        content: (callback) => append(pending.content, callback),
        row: (callback) => append(pending.row, callback),
        load: (callback) => append(pending.load, callback),
        change: (callback) => append(pending.change, callback),
        options: (callback) => append(pending.options, callback),
      },
      {
        get(target, key, receiver) {
          if (!Object.hasOwn(target, key)) {
            throw new Error(
              `Unknown select customization spec member: ${String(key)}`
            );
          }
          return Reflect.get(target, key, receiver);
        },
      }
    );
    const succeeded = withTransformerErrorHandling(() => {
      try {
        const result = setup(spec, { ...names });
        if (
          result &&
          typeof (result as PromiseLike<unknown>).then === "function"
        ) {
          // A rejected async setup must not also escape as an unhandled rejection.
          void Promise.resolve(result).catch(() => {});
          throw new Error("Select customization setup must be synchronous");
        }
        return true;
      } finally {
        sealed = true;
      }
    });
    if (succeeded) {
      this.#steps.content.push(...pending.content);
      this.#steps.row.push(...pending.row);
      this.#steps.options.push(...pending.options);
      this.#steps.optionsTiers.push(...pending.options.map(() => tier));
      this.#steps.load.push(...pending.load);
      this.#steps.change.push(...pending.change);
    }
  }
}
