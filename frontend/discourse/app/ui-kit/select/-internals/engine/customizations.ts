import { assert } from "@ember/debug";
import {
  applyMutableValueTransformer,
  withTransformerErrorHandling,
} from "discourse/lib/transformer";
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

/** Live data shared by the four customization points. */
export interface SelectCustomizationContext extends SelectNames {
  /** Data published by the recipe. */
  kindContext: object;
  /** Data published by the call site. */
  instanceContext: object;
}

/** What a content step receives. */
export interface SelectContentContext extends SelectCustomizationContext {
  /** The current query. */
  filter: string;
  /** The normalized controlled value. */
  value: SelectValue;
  /** The live select handle; only read it while building content. */
  control: SelectControl;
}

/** Presentation starts fresh for every option row evaluation. */
export interface SelectRowPresentation {
  /** Classes appended to the core classes; falsy entries are ignored. */
  classes: (string | false | null | undefined | 0)[];
}

/** State of the option row being presented. */
export interface SelectRowContext extends SelectCustomizationContext {
  /** The raw item behind the row. */
  item: SelectItem;
  /** Whether the item is held. */
  selected: boolean;
  /** Whether activation is disabled. */
  disabled: boolean;
}

/** What a load step receives; it runs once per query. */
export interface SelectLoadContext extends SelectCustomizationContext {
  /** The query being loaded. */
  filter: string;
  /** The live select handle. */
  control: SelectControl;
}

/** The proposed selection, before the controlled consumer is called. */
export interface SelectChangeContext extends SelectCustomizationContext {
  /** The proposed value, coerced to the source's id types. */
  value: SelectValue;
  /** Best-effort resolved items, with the select's single/multiple arity. */
  items: SelectItem | SelectItem[] | null;
}

/** A content step replaces the list passed to the following step. */
type Content = (
  items: SelectItem[],
  context: SelectContentContext
) => SelectItem[];
/** A row step mutates presentation; its return value is ignored. */
type Row = (row: SelectRowPresentation, context: SelectRowContext) => void;
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

  /** Loader steps, in declaration order. */
  load: Load[] = [];

  /** Change middleware, in declaration order. */
  change: Change[] = [];
}

/** Collects sealed, per-select declarations and isolates each runtime invocation. */
export default class SelectCustomizations {
  /** Only declarations from successful setups reach the runtime points. */
  #steps = new Declarations();

  /** Collects all registrations before running matching setups in tier order. */
  constructor(names: SelectNames) {
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

    for (const setup of tiers.flat()) {
      this.#setup(setup, names);
    }
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
    const row: SelectRowPresentation = { classes: [] };
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

  /** Seals even failed setups and discards every declaration they made. */
  #setup(setup: Setup, names: SelectNames): void {
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
      this.#steps.load.push(...pending.load);
      this.#steps.change.push(...pending.change);
    }
  }
}
