import { DEBUG } from "@glimmer/env";
import { capitalize } from "@ember/string";
import { isTesting } from "discourse/lib/environment";
import {
  BEHAVIOR_TRANSFORMERS,
  VALUE_TRANSFORMERS,
} from "discourse/lib/registry/transformers";
import { consolePrefix } from "discourse/lib/source-identifier";

/** The registration category of a transformer. */
export type TransformerType = "BEHAVIOR" | "VALUE";

/**
 * Context copied for a behavior chain, including its optional calling instance.
 * @typeParam C - Properties supplied by the caller before the calling instance is added.
 */
export type BehaviorTransformerContext<
  C extends object = Record<string, unknown>,
> = C & { _unstable_self?: unknown };

/**
 * A value hook receives the current value and the original, optional context.
 * @typeParam T - The value passed to the callback.
 * @typeParam C - Properties of the optional context object.
 */
export type ValueTransformer<
  T = unknown,
  C extends object = Record<string, unknown>,
> = (args: {
  /** The result of the preceding transformer, or the default value. */
  value: T;
  /** The context passed when applying the hook. */
  context: C | null | undefined;
}) => T;

/**
 * Mutates the supplied value; the pipeline ignores the callback's return value.
 * @typeParam T - The value to mutate.
 * @typeParam C - Properties of the optional context object.
 */
export type MutableValueTransformer<
  T = unknown,
  C extends object = Record<string, unknown>,
> = (args: Parameters<ValueTransformer<T, C>>[0]) => void;

/**
 * Either kind of value callback, as accepted at registration.
 *
 * A union with `MutableValueTransformer` would accept any return type, because a function returning a value is
 * assignable to one returning `void`. Returning `T | void` keeps the result checked.
 *
 * @typeParam T - The value passed to the callback.
 * @typeParam C - Properties of the optional context object.
 */
export type AnyValueTransformer<
  T = unknown,
  C extends object = Record<string, unknown>,
> = (args: Parameters<ValueTransformer<T, C>>[0]) => T | void;

/**
 * The core implementation called after the behavior middleware.
 * @typeParam R - The default implementation's result, including a Promise for async behavior.
 * @typeParam C - Properties supplied in the context before the calling instance is added.
 */
export type DefaultBehaviorTransformer<
  R = unknown,
  C extends object = Record<string, unknown>,
> = (args: {
  /** A shallow copy of the supplied context, shared throughout the chain. */
  context: BehaviorTransformerContext<C>;
}) => R;

/**
 * The result of a behavior chain. Middleware can stop the chain and return `void`, and async middleware that awaits
 * `next()` resolves to `Awaited<R> | void`.
 *
 * The check is not distributive, so a union of promise results gets a single combined promise.
 *
 * @typeParam R - The default implementation's result.
 */
export type BehaviorTransformerResult<R> =
  | R
  | void
  | ([Extract<R, Promise<unknown>>] extends [never]
      ? never
      : Promise<Awaited<R> | void>);

/**
 * Behavior middleware may continue the chain or replace the default behavior.
 * @typeParam R - The expected behavior result; middleware and next() may also return void.
 * @typeParam C - Properties supplied in the context before the calling instance is added.
 */
export type BehaviorTransformer<
  R = unknown,
  C extends object = Record<string, unknown>,
> = (args: {
  /** Runs the remaining middleware and default behavior; an exhausted chain returns undefined. */
  next: () => BehaviorTransformerResult<R>;
  /** A shallow copy of the supplied context, shared throughout the chain. */
  context: BehaviorTransformerContext<C>;
}) => BehaviorTransformerResult<R>;

type TransformerSource = "CORE" | "PLUGIN";

interface TransformerInfo {
  name: string;
  source: TransformerSource;
}

const CORE_TRANSFORMER = "CORE";
const PLUGIN_TRANSFORMER = "PLUGIN";

export const transformerTypes = Object.freeze({
  // key and value must match
  BEHAVIOR: "BEHAVIOR",
  VALUE: "VALUE",
} as const);

/**
 * Test flag - disables throwing an exception if applying a transformer fails on tests
 */
let skipApplyExceptionOnTests = false;

/**
 * Valid core transformer names initialization.
 *
 * Some checks are performed to ensure there are no repeated names between the multiple transformer types.
 *
 * The list can be edited in `discourse/lib/registry/transformers`
 */
let validTransformerNames = new Map<string, TransformerSource>();

// Core names must be lowercase and unique across transformer categories.
[
  [BEHAVIOR_TRANSFORMERS, transformerTypes.BEHAVIOR] as const,
  [VALUE_TRANSFORMERS, transformerTypes.VALUE] as const,
].forEach(([list, transformerType]) => {
  list.forEach((name) => {
    if (DEBUG) {
      if (name !== name.toLowerCase()) {
        throw new Error(
          `Transformer name "${name}" must be lowercase. Found in ${transformerType} transformers.`
        );
      }

      const existingInfo = findTransformerInfoByName(name);

      if (existingInfo) {
        const candidateName = `${name}/${transformerType.toLowerCase()}`;

        throw new Error(
          `Transformer name "${candidateName}" can't be added. The transformer ${existingInfo.name} already exists.`
        );
      }
    }

    validTransformerNames.set(
      _normalizeTransformerName(name, transformerType),
      CORE_TRANSFORMER
    );
  });
});

/** Hook names are extensible, so callback types are erased while stored. */
const transformersRegistry = new Map<string, unknown[]>();

/**
 * Indicates if the registry is open for registration.
 *
 * When the registry is closed, the system accepts adding new transformer names and throws an error when trying to
 * register a transformer.
 *
 * When the registry is open, the system will throw an error if a transformer name is added and will accept registering
 * transformers to be applied.
 */
let registryOpened = false;

/**
 * Freezes the valid transformers list and open the registry to accept new transform registrations.
 *
 * INTERNAL API: to be used only in `initializers/freeze-valid-transformers`
 */
export function _freezeValidTransformerNames(): void {
  registryOpened = true;
}

function _normalizeTransformerName(name: string, type: string): string {
  return `${name}/${type.toLowerCase()}`;
}

/**
 * Adds a new valid transformer name.
 *
 * INTERNAL API: use pluginApi.addValueTransformerName or pluginApi.addBehaviorTransformerName instead.
 *
 * DO NOT USE THIS FUNCTION TO ADD CORE TRANSFORMER NAMES. Instead register them directly in the
 * validTransformerNames set above.
 *
 * @param name - the name to register
 * @param transformerType - the type of the transformer being added
 */
export function _addTransformerName(
  name: string,
  transformerType: TransformerType
): void {
  const prefix = () =>
    `${consolePrefix()} api.add${capitalize(
      transformerType.toLowerCase()
    )}TransformerName`.trim();

  if (name !== name.toLowerCase()) {
    throw new Error(
      `${prefix()}: transformer name "${name}" must be lowercase.`
    );
  }

  if (registryOpened) {
    throw new Error(
      `${prefix()} was called when the system is no longer accepting new names to be added. ` +
        `Move your code to a pre-initializer that runs before "freeze-valid-transformers" to avoid this error.`
    );
  }

  const existingInfo = findTransformerInfoByName(name);

  if (!existingInfo) {
    validTransformerNames.set(
      _normalizeTransformerName(name, transformerType),
      PLUGIN_TRANSFORMER
    );

    return;
  }

  if (existingInfo.source === CORE_TRANSFORMER) {
    // eslint-disable-next-line no-console
    console.warn(
      `${prefix()}: transformer "${name}" matches existing core transformer "${
        existingInfo.name
      }" and shouldn't be re-registered using the API.`
    );
    return;
  }

  // eslint-disable-next-line no-console
  console.warn(
    `${prefix()}: transformer "${existingInfo.name}" is already registered`
  );
}

/**
 * Registers a transformer.
 *
 * INTERNAL API: use pluginApi.registerBehaviorTransformer or pluginApi.registerValueTransformer instead.
 *
 * @typeParam T - The value passed to the callback.
 * @typeParam C - Properties of the optional context object.
 * @param transformerName - the name of the transformer
 * @param transformerType - the type of the transformer being registered
 * @param callback - callback that will transform the value.
 * @returns True if the transformer exists, false if the name is unknown and the callback was ignored.
 */
export function _registerTransformer<T, C extends object>(
  transformerName: string,
  transformerType: "VALUE",
  callback: AnyValueTransformer<T, C>
): boolean;
/**
 * Registers behavior middleware through the internal API.
 * @typeParam R - The expected behavior result, in addition to a possible void result.
 * @typeParam C - Properties supplied in the context before the calling instance is added.
 */
export function _registerTransformer<R, C extends object>(
  transformerName: string,
  transformerType: "BEHAVIOR",
  callback: BehaviorTransformer<R, C>
): boolean;
export function _registerTransformer(
  transformerName: string,
  transformerType: TransformerType,
  callback: (...args: never[]) => unknown
): boolean {
  if (!transformerTypes[transformerType]) {
    throw new Error(`Invalid transformer type: ${transformerType}`);
  }
  const prefix = () =>
    `${consolePrefix()} api.register${capitalize(
      transformerType.toLowerCase()
    )}Transformer`.trim();

  if (!registryOpened) {
    throw new Error(
      `${prefix()} was called while the system was still accepting new transformer names to be added.\n` +
        `Move your code to an initializer or a pre-initializer that runs after "freeze-valid-transformers" to avoid this error.`
    );
  }

  const normalizedTransformerName = _normalizeTransformerName(
    transformerName,
    transformerType
  );

  if (!transformerNameExists(normalizedTransformerName)) {
    // eslint-disable-next-line no-console
    console.warn(
      `${prefix()}: transformer "${transformerName}" is unknown and will be ignored. ` +
        "Is the name correct? Are you using the correct API for the transformer type?"
    );

    return false;
  }

  if (typeof callback !== "function") {
    throw new Error(
      `${prefix()} requires the callback argument to be a function`
    );
  }

  const existingTransformers =
    transformersRegistry.get(normalizedTransformerName) || [];

  existingTransformers.push(callback);

  transformersRegistry.set(normalizedTransformerName, existingTransformers);

  return true;
}

/**
 * Applies middleware in registration order, with the core implementation last.
 * @typeParam R - The result inferred from the default callback; middleware may also return void.
 * @typeParam C - Properties inferred from the supplied context object.
 */
export function applyBehaviorTransformer<
  R,
  C extends object = Record<string, unknown>,
>(
  this: unknown,
  transformerName: string,
  defaultCallback: DefaultBehaviorTransformer<R, C>,
  context?: C | null
): BehaviorTransformerResult<R> {
  const normalizedTransformerName = _normalizeTransformerName(
    transformerName,
    transformerTypes.BEHAVIOR
  );

  const prefix = () => `${consolePrefix()} applyBehaviorTransformer`.trim();

  if (!transformerNameExists(normalizedTransformerName)) {
    throw new Error(
      `${prefix()}: transformer name "${transformerName}" does not exist. ` +
        "Was the transformer name properly added? Is the transformer name correct? Is the type equals BEHAVIOR? " +
        "applyBehaviorTransformer can only be used with BEHAVIOR transformers."
    );
  }

  if (typeof defaultCallback !== "function") {
    throw new Error(
      `${prefix()} requires the callback argument to be a function`
    );
  }

  if (
    context != null &&
    !(typeof context === "object" && context.constructor === Object)
  ) {
    throw `${prefix()}("${transformerName}", ...): context must be a simple JS object or nullish.`;
  }

  // Registration and application must agree on the contract for this hook name.
  const transformers = transformersRegistry.get(normalizedTransformerName) as
    | BehaviorTransformer<R, C>[]
    | undefined;
  // Spreading an optional generic context loses C in TypeScript.
  const appliedContext = { ...context } as BehaviorTransformerContext<C>;
  if (!appliedContext._unstable_self && this) {
    appliedContext._unstable_self = this;
  }

  if (!transformers) {
    return defaultCallback({ context: appliedContext });
  }

  const callbackQueue = [...transformers, defaultCallback];

  function nextCallback(): BehaviorTransformerResult<R> {
    const currentCallback = callbackQueue.shift();

    if (!currentCallback) {
      return;
    }

    // do not surround the default implementation in the try ... catch block
    if (currentCallback === defaultCallback) {
      // Equality identifies the default callback, whose arguments omit next.
      return (currentCallback as DefaultBehaviorTransformer<R, C>)({
        context: appliedContext,
      });
    }

    try {
      return currentCallback({ context: appliedContext, next: nextCallback });
    } catch (error) {
      document.dispatchEvent(
        new CustomEvent("discourse-error", {
          detail: { messageKey: "broken_transformer_alert", error },
        })
      );

      if (isTesting() && !skipApplyExceptionOnTests) {
        throw error;
      }

      // if the current callback failed keep processing the callback queue
      // hopefully the application won't be left in a broken state
      return nextCallback();
    }
  }

  return nextCallback();
}

/**
 * Apply a transformer to a value.
 *
 * @typeParam T - The result type, inferred from the default value; specify a wider type when needed.
 * @typeParam C - Properties inferred from the optional context object.
 *
 * @param transformerName - The name of the transformer applied
 * @param defaultValue - The default value
 * @param context - The optional context to pass to the transformer callbacks
 * @param opts - Options for the transformer
 * @throws If the transformer name does not exist or the context is invalid
 */
export function applyValueTransformer<
  T,
  C extends object = Record<string, unknown>,
>(
  transformerName: string,
  defaultValue: T,
  context?: C | null,
  opts: {
    /** Mutate the original value and ignore callback return values. */
    mutable?: boolean;
  } | null = { mutable: false }
): T {
  const normalizedTransformerName = _normalizeTransformerName(
    transformerName,
    transformerTypes.VALUE
  );

  const prefix = () => `${consolePrefix()} applyValueTransformer`.trim();

  if (!transformerNameExists(normalizedTransformerName)) {
    throw new Error(
      `${prefix()}: transformer name "${transformerName}" does not exist. ` +
        "Was the transformer name properly added? Is the transformer name correct? Is the type equals VALUE? " +
        "applyValueTransformer can only be used with VALUE transformers."
    );
  }

  if (
    context != null &&
    !(
      typeof context === "object" &&
      (context.constructor === Object || context.constructor === undefined)
    )
  ) {
    throw (
      `${prefix()}("${transformerName}", ...): context must be a simple JS object/an Ember hash or nullish.\n` +
      "Avoid passing complex objects in the context, like for example, component instances or objects that carry " +
      "mutable state directly. This can induce users to registry transformers with callbacks causing side effects " +
      "and mutating the context directly. Inevitably, this leads to fragile integrations."
    );
  }

  // Registration and application must agree on the contract for this hook name.
  const transformers = transformersRegistry.get(normalizedTransformerName) as
    | ValueTransformer<T, C>[]
    | undefined;

  if (!transformers) {
    return defaultValue;
  }

  const mutable = opts?.mutable; // flag indicating if the value should be mutated instead of returned
  let newValue = defaultValue;

  const transformerPoolSize = transformers.length;
  for (let i = 0; i < transformerPoolSize; i++) {
    const valueCallback = transformers[i];

    try {
      const value = valueCallback({ value: newValue, context });

      if (!mutable) {
        newValue = value;
      }
    } catch (error) {
      document.dispatchEvent(
        new CustomEvent("discourse-error", {
          detail: { messageKey: "broken_transformer_alert", error },
        })
      );

      if (isTesting() && !skipApplyExceptionOnTests) {
        throw error;
      }
    }
  }

  return newValue;
}

/**
 * Apply a transformer to a mutable value.
 * The registered transformers should mutate the value instead of returning it.
 *
 * @typeParam T - The original value's type, preserved in the returned reference.
 * @typeParam C - Properties inferred from the optional context object.
 *
 * @param transformerName - The name of the transformer applied
 * @param defaultValue - The default value
 * @param context - The optional context to pass to the transformer callbacks
 * @throws If the transformer name does not exist or the context is invalid
 */
export function applyMutableValueTransformer<
  T,
  C extends object = Record<string, unknown>,
>(transformerName: string, defaultValue: T, context?: C | null): T {
  return applyValueTransformer(transformerName, defaultValue, context, {
    mutable: true,
  });
}

/**
 * Find a transformer info by name, without considering the type
 *
 * @param name - the name of the transformer
 *
 */
function findTransformerInfoByName(name: string): TransformerInfo | null {
  for (const searchedType of Object.keys(transformerTypes)) {
    const searchedName = _normalizeTransformerName(name, searchedType);
    const source = validTransformerNames?.get(searchedName);

    if (source) {
      return { name: searchedName, source };
    }
  }

  return null;
}

/**
 * Check if a transformer name exists
 *
 * @param normalizedName - the normalized name to check
 */
function transformerNameExists(normalizedName: string): boolean {
  return validTransformerNames.has(normalizedName);
}

/**
 * Check if a transformer was added
 *
 * @param name - the name to check
 * @param type - the type of the transformer
 *
 */
export function transformerWasAdded(
  name: string,
  type: TransformerType
): boolean {
  return validTransformerNames.has(_normalizeTransformerName(name, type));
}

/**
 * Stores the initial state of `registryOpened` to allow the correct reset after a test that needs to manually
 * override the registry opened state finishes running.
 *
 */
let testRegistryOpenedState: boolean | null = null;

/**
 * Opens the transformers registry for registration
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function acceptNewTransformerNames(): void {
  if (!isTesting()) {
    throw new Error("Use `acceptNewTransformerNames` only in tests.");
  }

  if (testRegistryOpenedState === null) {
    testRegistryOpenedState = registryOpened;
  }

  registryOpened = false;
}

/**
 * Closes the transformers registry for registration
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function acceptTransformerRegistrations(): void {
  if (!isTesting()) {
    throw new Error("Use `acceptTransformerRegistrations` only in tests.");
  }

  if (testRegistryOpenedState === null) {
    testRegistryOpenedState = registryOpened;
  }

  registryOpened = true;
}

/**
 * Resets the transformers initial state
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function resetTransformers(): void {
  if (!isTesting()) {
    throw new Error("Use `resetTransformers` only in tests.");
  }

  if (testRegistryOpenedState !== null) {
    registryOpened = testRegistryOpenedState;
  }

  clearPluginTransformers();
  acceptNewTransformerNames();
  transformersRegistry.clear();
  skipApplyExceptionOnTests = false;
}

/**
 * Clears all transformer names registered using the plugin API
 */
function clearPluginTransformers(): void {
  validTransformerNames = new Map(
    [...validTransformerNames].filter(([, type]) => type === CORE_TRANSFORMER)
  );
}

/**
 * Disables throwing the exception when applying the transformers in a test environment
 *
 * It's only to test if the exception in handled properly
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function disableThrowingApplyExceptionOnTests(): void {
  skipApplyExceptionOnTests = true;
}
