import { DEBUG } from "@glimmer/env";
import { capitalize } from "@ember/string";
import { isTesting } from "discourse/lib/environment";
import {
  BEHAVIOR_TRANSFORMERS,
  type BehaviorTransformerRegistry,
  type Untyped,
  VALUE_TRANSFORMERS,
  type ValueTransformerRegistry,
} from "discourse/lib/registry/transformers";
import { consolePrefix } from "discourse/lib/source-identifier";

export type {
  BehaviorTransformerRegistry,
  Untyped,
  ValueTransformerRegistry,
} from "discourse/lib/registry/transformers";

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

type ValueName = keyof ValueTransformerRegistry & string;
type BehaviorName = keyof BehaviorTransformerRegistry & string;

type IsAny<T> = 0 extends 1 & T ? true : false;

type IsUntyped<E> = [E] extends [never]
  ? false
  : IsAny<E> extends true
    ? false
    : [E] extends [Untyped]
      ? true
      : false;

type TypedKeys<R> = {
  [K in keyof R]: IsUntyped<R[K]> extends true ? never : K;
}[keyof R];

type TypedName =
  | TypedKeys<ValueTransformerRegistry>
  | TypedKeys<BehaviorTransformerRegistry>;

type IsUnion<T, Whole = T> = T extends Whole
  ? [Whole] extends [T]
    ? false
    : true
  : never;

type IsSingle<T> = [T] extends [never]
  ? false
  : IsAny<T> extends true
    ? false
    : true extends IsUnion<T>
      ? false
      : true;

/** Branded literals must index by the registry's literal key, not by their intersection. */
type Canonical<K, N extends string> = {
  [P in N]: [K] extends [P] ? P : never;
}[N];

declare const invalidTransformerName: unique symbol;
declare const invalidTransformerEntry: unique symbol;

type InvalidTransformerEntry = {
  [invalidTransformerEntry]: "The registry entry for this hook is malformed";
};

type FallbackGuard<K extends string> =
  IsSingle<K> extends true
    ? string extends K
      ? { [invalidTransformerName]: "Use a single untyped hook name" }
      : [K & TypedName] extends [never]
        ? unknown
        : { [invalidTransformerName]: "Use the registered hook contract" }
    : { [invalidTransformerName]: "Use a single hook name" };

type ValueEntry<K extends string> = ValueTransformerRegistry[Canonical<
  K,
  ValueName
>];
type BehaviorEntry<K extends string> = BehaviorTransformerRegistry[Canonical<
  K,
  BehaviorName
>];

type ValidValueEntry<E> =
  IsSingle<E> extends true
    ? [E] extends [
        { value: infer V; context: object | undefined; mutable: infer M },
      ]
      ? [M] extends [never]
        ? false
        : [M] extends [true]
          ? true
          : [M] extends [false]
            ? [V] extends [void]
              ? [void] extends [V]
                ? false
                : true
              : true
            : false
      : false
    : false;

type ValidBehaviorEntry<E> =
  IsSingle<E> extends true
    ? [E] extends [{ result: unknown; context: object | undefined }]
      ? true
      : false
    : false;

type ValueOf<E> = E extends { value: infer V } ? V : never;
type ContextOf<E> = E extends { context: infer C } ? C : never;
type ResultOf<E> = E extends { result: infer R } ? R : never;

type ValueContext<C> = undefined extends C ? C | null : C;
type BehaviorContext<C> = [C] extends [undefined]
  ? { _unstable_self?: unknown }
  : undefined extends C
    ? Partial<Exclude<C, undefined>> & { _unstable_self?: unknown }
    : C & { _unstable_self?: unknown };

type ContextArguments<C> = undefined extends C
  ? [context?: C | null]
  : [context: C];

type RegisteredValueCallback<E> = (args: {
  value: ValueOf<E>;
  context: ValueContext<ContextOf<E>>;
}) => E extends { mutable: true } ? void : ValueOf<E>;

type RegisteredBehaviorCallback<E> = (args: {
  next: () => BehaviorTransformerResult<ResultOf<E>>;
  context: BehaviorContext<ContextOf<E>>;
}) => BehaviorTransformerResult<ResultOf<E>>;

type RegisteredDefaultBehavior<E> = (args: {
  context: BehaviorContext<ContextOf<E>>;
}) => ResultOf<E>;

/**
 * Callback for a single value hook. Its registry entry determines value, context, and mutability.
 * Unregistered and `Untyped` hooks retain the generic callback contract; malformed entries and unions yield `never`.
 */
export type ValueTransformerFor<K extends string> =
  IsSingle<K> extends true
    ? [Canonical<K, ValueName>] extends [never]
      ? unknown extends FallbackGuard<K>
        ? AnyValueTransformer
        : never
      : IsUntyped<ValueEntry<K>> extends true
        ? AnyValueTransformer
        : ValidValueEntry<ValueEntry<K>> extends true
          ? RegisteredValueCallback<ValueEntry<K>>
          : never
    : never;

/**
 * Middleware for a single behavior hook, including the registry's result and copied context.
 * Unregistered and `Untyped` hooks retain the generic contract; malformed entries and unions yield `never`.
 */
export type BehaviorTransformerFor<K extends string> =
  IsSingle<K> extends true
    ? [Canonical<K, BehaviorName>] extends [never]
      ? unknown extends FallbackGuard<K>
        ? BehaviorTransformer
        : never
      : IsUntyped<BehaviorEntry<K>> extends true
        ? BehaviorTransformer
        : ValidBehaviorEntry<BehaviorEntry<K>> extends true
          ? RegisteredBehaviorCallback<BehaviorEntry<K>>
          : never
    : never;

type ValueRegistrationArguments<K extends ValueName, T, C extends object> =
  IsSingle<K> extends true
    ? IsUntyped<ValueEntry<K>> extends true
      ? [callback: AnyValueTransformer<T, C>]
      : ValidValueEntry<ValueEntry<K>> extends true
        ? [callback: ValueTransformerFor<K>]
        : [callback: InvalidTransformerEntry]
    : [callback: never];

type BehaviorRegistrationArguments<
  K extends BehaviorName,
  R,
  C extends object,
> =
  IsSingle<K> extends true
    ? IsUntyped<BehaviorEntry<K>> extends true
      ? [callback: BehaviorTransformer<R, C>]
      : ValidBehaviorEntry<BehaviorEntry<K>> extends true
        ? [callback: BehaviorTransformerFor<K>]
        : [callback: InvalidTransformerEntry]
    : [callback: never];

type ValueApplyArguments<
  K extends ValueName,
  M extends boolean,
  T,
  C extends object,
> =
  IsSingle<K> extends true
    ? IsUntyped<ValueEntry<K>> extends true
      ? [defaultValue: T, context?: C | null]
      : ValidValueEntry<ValueEntry<K>> extends true
        ? ValueEntry<K> extends { mutable: M }
          ? [
              defaultValue: ValueOf<ValueEntry<K>>,
              ...ContextArguments<ContextOf<ValueEntry<K>>>,
            ]
          : [
              defaultValue: {
                [invalidTransformerEntry]: "Use the apply function matching this hook's mutability";
              },
            ]
        : [defaultValue: InvalidTransformerEntry]
    : [defaultValue: never];

/** Binding without a concrete name must preserve the generic result; arguments still reject name unions. */
type ValueApplyResult<K extends ValueName, T> = [
  Canonical<K, ValueName>,
] extends [never]
  ? T
  : IsUntyped<ValueEntry<K>> extends true
    ? T
    : ValueOf<ValueEntry<K>>;

type BehaviorApplyArguments<K extends BehaviorName, R, C extends object> =
  IsSingle<K> extends true
    ? IsUntyped<BehaviorEntry<K>> extends true
      ? [defaultCallback: DefaultBehaviorTransformer<R, C>, context?: C | null]
      : ValidBehaviorEntry<BehaviorEntry<K>> extends true
        ? [
            defaultCallback: RegisteredDefaultBehavior<BehaviorEntry<K>>,
            ...ContextArguments<ContextOf<BehaviorEntry<K>>>,
          ]
        : [defaultCallback: InvalidTransformerEntry]
    : [defaultCallback: never];

type BehaviorApplyResult<K extends BehaviorName, R> = BehaviorTransformerResult<
  IsUntyped<BehaviorEntry<K>> extends true ? R : ResultOf<BehaviorEntry<K>>
>;

/** Registers value callbacks using a name's contract, or generic inference for untyped names. */
export interface RegisterValueTransformer {
  /**
   * Register a transformer to override values defined in Discourse.
   *
   * Example: return a static value
   * ```
   * api.registerValueTransformer("example-transformer", () => "value");
   * ```
   *
   * Example: transform the current value
   * ```
   * api.registerValueTransformer("example-transformer", ({value}) => value * 10);
   * ```
   *
   * Example: transform the current value based on a context property
   * ```
   * api.registerValueTransformer("example-transformer", ({value, context}) => {
   *   if (context.property) {
   *     return value * 10;
   *   }
   *
   *   return value;
   * });
   * ```
   *
   * Callbacks receive the current value and context. Return the transformed value without side effects.
   * For hooks applied with `applyMutableValueTransformer`, mutate the value instead; returns are ignored.
   *
   * @returns True if the transformer exists, false otherwise.
   */
  <K extends string, T = unknown, C extends object = Record<string, unknown>>(
    name: K & FallbackGuard<K>,
    callback: AnyValueTransformer<T, C>
  ): boolean;
  /**
   * Register a value transformer whose registry entry fixes its value, context, and return contract.
   * See {@link ValueTransformerFor} for the callback type.
   *
   * @returns True if the transformer exists, false otherwise.
   */
  <
    K extends ValueName,
    T = unknown,
    C extends object = Record<string, unknown>,
  >(
    name: K,
    ...args: ValueRegistrationArguments<K, T, C>
  ): boolean;
}

/** Registers behavior middleware using a name's contract, or generic inference for untyped names. */
export interface RegisterBehaviorTransformer {
  /**
   * Register a transformer to override behavior defined in Discourse.
   *
   * Example: to perform an action before the expected behavior
   * ```
   * api.registerBehaviorTransformer("example-transformer", ({next, context}) => {
   *   exampleNewAction(); // action performed before the expected behavior
   *
   *   next(); //iterates over the transformer queue processing the behaviors
   * });
   * ```
   *
   * Example: to perform an action after the expected behavior
   * ```
   * api.registerBehaviorTransformer("example-transformer", ({next, context}) => {
   *   next(); //iterates over the transformer queue processing the behaviors
   *
   *   exampleNewAction(); // action performed after the expected behavior
   * });
   * ```
   *
   * Example: to use a value returned by the expected behavior to decide if an action must be performed
   * ```
   * api.registerBehaviorTransformer("example-transformer", ({next, context}) => {
   *   const expected = next(); //iterates over the transformer queue processing the behaviors
   *
   *   if (expected === "EXPECTED") {
   *     exampleNewAction(); // action performed after the expected behavior
   *   }
   * });
   * ```
   *
   * Example: to abort the expected behavior based on a condition
   * ```
   * api.registerBehaviorTransformer("example-transformer", ({next, context}) => {
   *   if (context.property) {
   *     // not calling next() on a behavior transformer aborts executing the expected behavior
   *
   *     return;
   *   }
   *
   *   next();
   * });
   * ```
   *
   * Middleware can call `next()` to run the remaining queue, including the default behavior.
   * Omitting `next()` completely overrides the default behavior.
   *
   * @returns True if the transformer exists, false otherwise.
   */
  <K extends string, R = unknown, C extends object = Record<string, unknown>>(
    name: K & FallbackGuard<K>,
    callback: BehaviorTransformer<R, C>
  ): boolean;
  /**
   * Register behavior middleware whose registry entry fixes its result and context contract.
   * See {@link BehaviorTransformerFor} for the callback type.
   *
   * @returns True if the transformer exists, false otherwise.
   */
  <
    K extends BehaviorName,
    R = unknown,
    C extends object = Record<string, unknown>,
  >(
    name: K,
    ...args: BehaviorRegistrationArguments<K, R, C>
  ): boolean;
}

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
 * Internal value registration; use the Plugin API to register callbacks.
 * @returns True if the transformer exists, false if the name is unknown and the callback was ignored.
 */
export function _registerTransformer<
  K extends string,
  T = unknown,
  C extends object = Record<string, unknown>,
>(
  transformerName: K & FallbackGuard<K>,
  transformerType: "VALUE",
  callback: AnyValueTransformer<T, C>
): boolean;
/**
 * Internal behavior registration; use the Plugin API to register middleware.
 * @returns True if the transformer exists, false if the name is unknown and the callback was ignored.
 */
export function _registerTransformer<
  K extends string,
  R = unknown,
  C extends object = Record<string, unknown>,
>(
  transformerName: K & FallbackGuard<K>,
  transformerType: "BEHAVIOR",
  callback: BehaviorTransformer<R, C>
): boolean;
/**
 * Registers a value callback according to its hook's contract.
 * @returns True if the transformer exists, false if the name is unknown and the callback was ignored.
 */
export function _registerTransformer<
  K extends ValueName,
  T = unknown,
  C extends object = Record<string, unknown>,
>(
  transformerName: K,
  transformerType: "VALUE",
  ...args: ValueRegistrationArguments<K, T, C>
): boolean;
/**
 * Registers behavior middleware according to its hook's contract.
 * @returns True if the transformer exists, false if the name is unknown and the callback was ignored.
 */
export function _registerTransformer<
  K extends BehaviorName,
  R = unknown,
  C extends object = Record<string, unknown>,
>(
  transformerName: K,
  transformerType: "BEHAVIOR",
  ...args: BehaviorRegistrationArguments<K, R, C>
): boolean;
export function _registerTransformer(
  transformerName: string,
  transformerType: TransformerType,
  callback: unknown
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
 * Applies untyped middleware in registration order, with the default implementation last.
 * @param transformerName - The name of the transformer applied
 * @param defaultCallback - The default implementation run after the middleware
 * @param context - The context copied into the behavior chain
 * @throws If the transformer name does not exist, the callback is not a function, or the context is invalid
 */
export function applyBehaviorTransformer<
  K extends string,
  R = unknown,
  C extends object = Record<string, unknown>,
>(
  this: unknown,
  transformerName: K & FallbackGuard<K>,
  defaultCallback: DefaultBehaviorTransformer<R, C>,
  context?: C | null
): BehaviorTransformerResult<R>;
/**
 * Applies a registered behavior hook with its declared result and context.
 * @param transformerName - The name of the transformer applied
 * @param defaultCallback - The default implementation run after the middleware
 * @param context - The context copied into the behavior chain
 * @throws If the transformer name does not exist, the callback is not a function, or the context is invalid
 */
export function applyBehaviorTransformer<
  K extends BehaviorName,
  R = unknown,
  C extends object = Record<string, unknown>,
>(
  this: unknown,
  transformerName: K,
  ...args: BehaviorApplyArguments<K, R, C>
): BehaviorApplyResult<K, R>;
export function applyBehaviorTransformer<
  R,
  C extends object = Record<string, unknown>,
>(
  this: unknown,
  transformerName: string,
  defaultCallback: DefaultBehaviorTransformer<R, C> | InvalidTransformerEntry,
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
 * Applies an untyped value hook, inferring its result from the default value.
 * @param transformerName - The name of the transformer applied
 * @param defaultValue - The default value
 * @param context - The context passed to the transformer callbacks
 * @param opts - Options for the transformer
 * @throws If the transformer name does not exist or the context is invalid
 */
export function applyValueTransformer<
  K extends string,
  T = unknown,
  C extends object = Record<string, unknown>,
>(
  transformerName: K & FallbackGuard<K>,
  defaultValue: T,
  context?: C | null,
  opts?: {
    /** Mutate the original value and ignore callback return values. */
    mutable?: boolean;
  } | null
): T;
/**
 * Applies an immutable registered hook with its declared value and context.
 * @param transformerName - The name of the transformer applied
 * @param defaultValue - The default value
 * @param context - The context passed to the transformer callbacks
 * @throws If the transformer name does not exist or the context is invalid
 */
export function applyValueTransformer<
  K extends ValueName,
  T = unknown,
  C extends object = Record<string, unknown>,
>(
  transformerName: K,
  ...args: ValueApplyArguments<K, false, T, C>
): ValueApplyResult<K, T>;
export function applyValueTransformer<
  T,
  C extends object = Record<string, unknown>,
>(
  transformerName: string,
  defaultValue: T,
  context?: C | null,
  opts: { mutable?: boolean } | null = { mutable: false }
): T {
  return applyValueTransformerInternal(
    transformerName,
    defaultValue,
    context,
    opts
  );
}

/** Shared implementation keeps the mutable option out of registered public signatures. */
function applyValueTransformerInternal<
  T,
  C extends object = Record<string, unknown>,
>(
  transformerName: string,
  defaultValue: T,
  context: C | null | undefined,
  opts: { mutable?: boolean } | null
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
 * Applies an untyped mutable hook, preserving the original value's type and reference.
 * @param transformerName - The name of the transformer applied
 * @param defaultValue - The default value
 * @param context - The context passed to the transformer callbacks
 * @throws If the transformer name does not exist or the context is invalid
 */
export function applyMutableValueTransformer<
  K extends string,
  T = unknown,
  C extends object = Record<string, unknown>,
>(
  transformerName: K & FallbackGuard<K>,
  defaultValue: T,
  context?: C | null
): T;
/**
 * Applies a mutable registered hook; callback return values are ignored.
 * @param transformerName - The name of the transformer applied
 * @param defaultValue - The default value
 * @param context - The context passed to the transformer callbacks
 * @throws If the transformer name does not exist or the context is invalid
 */
export function applyMutableValueTransformer<
  K extends ValueName,
  T = unknown,
  C extends object = Record<string, unknown>,
>(
  transformerName: K,
  ...args: ValueApplyArguments<K, true, T, C>
): ValueApplyResult<K, T>;
export function applyMutableValueTransformer<
  T,
  C extends object = Record<string, unknown>,
>(transformerName: string, defaultValue: T, context?: C | null): T {
  return applyValueTransformerInternal(transformerName, defaultValue, context, {
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
