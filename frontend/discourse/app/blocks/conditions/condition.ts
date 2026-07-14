import type { ArgSchema, BlockConstraints } from "discourse/blocks/types";
import { getByPath } from "discourse/lib/blocks";
import type { DebugLoggerInterface } from "discourse/lib/blocks/-internals/debug-hooks";

/**
 * Declares how a condition handles the `source` parameter.
 *
 * - `"none"`: `source` parameter is disallowed.
 * - `"outletArgs"`: `source` must be `@outletArgs.propertyPath`; the base
 *   class resolves it via outlet args.
 * - `"object"`: `source` is passed directly as an object (e.g., for settings).
 */
export type ConditionSourceType = "none" | "outletArgs" | "object";

/**
 * Custom validation function for a condition, run at registration time
 * against the condition's resolved args. Returns an error message (or
 * messages), or `null`/`undefined` when the args are valid.
 */
export type ConditionValidateFn = (
  args: Record<string, unknown>
) => string | string[] | null | undefined;

/**
 * The viewport read-surface a `viewport` condition checks against: the live
 * `capabilities` service, or a simulated payload of the same shape.
 */
export interface ViewportCapabilities {
  /** Per-breakpoint booleans, `true` when the viewport is at least that size. */
  viewport: Record<string, boolean>;

  /** Whether the device is touch-capable. */
  touch: boolean;
}

/**
 * A simulated identity/environment supplied by a preview/simulation context,
 * letting condition-gated visibility be evaluated under a hypothetical viewer
 * or viewport instead of the real services.
 */
export interface ConditionSimulation {
  /**
   * Simulated user. `null` means "simulated as anonymous"; an absent key means
   * the real `currentUser` service is used.
   */
  user?: unknown;

  /**
   * Simulated viewport capabilities. `null` or an absent key falls back to the
   * real `capabilities` service.
   */
  viewport?: ViewportCapabilities | null;
}

/**
 * Evaluation context passed to `evaluate()`, `resolveSource()`, and
 * `getResolvedValueForLogging()`. Built by the block render pipeline (and,
 * for nested route params, by the route condition itself).
 */
export interface ConditionContext {
  /** Whether debug logging is enabled for this evaluation. */
  debug?: boolean;

  /** Outlet args passed to the block, used to resolve `@outletArgs.*` sources. */
  outletArgs?: Record<string, unknown>;

  /** Current nesting depth, used for debug log indentation. */
  _depth?: number;

  /** Logger interface for nested debug logging (used by the route condition
   *  to log its OR/NOT/param sub-checks). */
  logger?: DebugLoggerInterface | null;

  /**
   * Optional simulated identity/environment from a preview/simulation context,
   * used to evaluate condition-gated visibility under a hypothetical viewer or
   * viewport rather than the real services.
   */
  simulation?: ConditionSimulation;
}

/**
 * Resolved-value info returned by `getResolvedValueForLogging()`, shown in
 * the dev-tools debug overlay. Conditions that don't resolve a value (e.g.
 * because `source` wasn't provided) return `undefined` instead.
 */
export interface ConditionResolvedValue {
  /** Always `true` when a value was resolved. */
  hasValue: true;

  /** The resolved value, for conditions that resolve via `source`. */
  value?: unknown;

  /** An additional annotation, e.g. a "did you mean" note for an unknown setting. */
  note?: string;

  /** An alternate formatted payload, for conditions with non-`source`
   *  resolution (e.g. the `outletArg` condition's `path`/`actual`/`configured` triple). */
  formatted?: unknown;
}

/**
 * Base class for all block conditions.
 *
 * Subclasses must:
 * - Use the `@blockCondition` decorator with `type` and `args` schema config
 * - Implement the `evaluate(args, context)` method
 * - Optionally provide a `validate` function in the decorator config for custom validation
 * - Optionally pass `sourceType` to the decorator to enable `source` parameter support
 *
 * Condition classes can inject services using `@service` decorator.
 * The Blocks service sets the owner on condition instances, enabling dependency injection.
 *
 * ## Validation Flow
 *
 * Validation happens at block registration time in this order:
 * 1. Unknown args are detected (typo detection with suggestions)
 * 2. Arg values are validated against the `args` schema (type, min, max, pattern, etc.)
 * 3. Constraints are validated (atLeastOne, exactlyOne, allOrNone, atMostOne)
 * 4. Source parameter is validated (based on sourceType)
 * 5. Custom `validate` function from decorator config is called (if provided)
 *
 * ## Source Parameter Support
 *
 * Conditions can declare support for the `source` parameter via `static sourceType`:
 *
 * - `"none"` (default): `source` parameter is disallowed
 * - `"outletArgs"`: `source` must be `@outletArgs.propertyPath`; base class resolves it
 * - `"object"`: `source` is passed directly as an object (e.g., for settings)
 *
 * When `sourceType` is `"outletArgs"`, use `resolveSource(args, context)` to get the
 * resolved value from outlet args.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @example
 * ```javascript
 * import { blockCondition, BlockCondition } from "discourse/blocks/conditions";
 *
 * @blockCondition({
 *   type: "my-condition",
 *   sourceType: "outletArgs",
 *   args: {
 *     requiredArg: { type: "string", required: true },
 *     optionalCount: { type: "number", min: 0, max: 10 },
 *   },
 *   validate(args) {
 *     // Custom validation that can't be expressed in schema
 *     if (args.requiredArg === "forbidden") {
 *       return "requiredArg cannot be 'forbidden'";
 *     }
 *     return null;
 *   }
 * })
 * export default class BlockMyCondition extends BlockCondition {
 *   @service myService;
 *
 *   evaluate(args, context) {
 *     // Get value from source (outlet args) or fall back to service
 *     const value = this.resolveSource(args, context) ?? this.myService.defaultValue;
 *     return this.myService.someCheck(value, args.requiredArg);
 *   }
 * }
 * ```
 */
export class BlockCondition {
  /**
   * Unique identifier for this condition type.
   * Used in condition specs: `{ type: "route", ... }`
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be set directly. Pass the `type` option to the decorator instead.
   */
  declare static type: string;

  /**
   * Declares how this condition handles the `source` parameter.
   *
   * - `"none"` (default): `source` parameter is disallowed
   * - `"outletArgs"`: `source` must be `@outletArgs.propertyPath`; base class resolves it
   * - `"object"`: `source` is passed directly as an object (e.g., settings object)
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be set directly. Pass the `sourceType` option to the decorator instead.
   */
  static sourceType: ConditionSourceType = "none";

  /**
   * Arg schema definitions for this condition.
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be overridden directly. The decorator creates a non-configurable getter
   * that returns a frozen object.
   */
  declare static argsSchema: Readonly<Record<string, ArgSchema>>;

  /**
   * Cross-arg constraint definitions for this condition.
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be overridden directly. The decorator creates a non-configurable getter
   * that returns a frozen object or undefined.
   */
  declare static constraints: Readonly<BlockConstraints> | undefined;

  /**
   * Custom validation function for this condition.
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be overridden directly. The decorator creates a non-configurable getter
   * that returns the validate function or undefined.
   */
  declare static validateFn: ConditionValidateFn | undefined;

  /**
   * Valid argument keys for this condition.
   *
   * This property is derived from the `args` schema by the `@blockCondition`
   * decorator and should not be overridden directly.
   *
   * The `source` key is automatically added by the decorator when
   * `sourceType !== "none"`.
   */
  declare static validArgKeys: readonly string[];

  /**
   * Namespace component parsed from `type`.
   *
   * - `null` for core conditions (e.g. `"route"`).
   * - The plugin or theme namespace for namespaced conditions
   *   (e.g. `"my-plugin"` for `"my-plugin:my-condition"`).
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be overridden directly.
   */
  static namespace;

  /**
   * Namespace kind parsed from `type`.
   *
   * - `"core"` for core conditions.
   * - `"plugin"` for `"plugin:condition-name"` types.
   * - `"theme"` for `"theme:namespace:condition-name"` types.
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be overridden directly.
   */
  static namespaceType;

  /**
   * Human-readable label for display purposes.
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be overridden directly. Pass the `displayName` option to the decorator
   * instead. Defaults to `null` so consumers can fall back to a titleCased
   * `type`.
   */
  static displayName;

  /**
   * Short human-readable description.
   *
   * This property is defined by the `@blockCondition` decorator and should not
   * be overridden directly. Pass the `description` option to the decorator
   * instead. Defaults to `null` so consumers can omit the description.
   */
  static description;

  /**
   * Resolves the `source` parameter value based on the condition's `sourceType`.
   *
   * - `sourceType: "outletArgs"`: Extracts the property path from `@outletArgs.path.to.value`
   *   and retrieves the corresponding value from `context.outletArgs`.
   * - `sourceType: "object"`: Returns the `source` value directly.
   *
   * @param args - The condition arguments containing `source`.
   * @param context - Evaluation context containing `outletArgs`.
   * @returns The resolved value from outlet args, or undefined if not found.
   */
  resolveSource(
    args: Record<string, unknown>,
    context?: ConditionContext
  ): unknown {
    const { source } = args;

    if (!source) {
      return undefined;
    }

    // Read via the constructor's statics, which the `@blockCondition`
    // decorator sets on every concrete subclass (never on this base class).
    const sourceType = (this.constructor as typeof BlockCondition).sourceType;

    if (sourceType === "object") {
      return source;
    }

    if (sourceType === "outletArgs") {
      // Extract path after "@outletArgs.". `source` is validated to be a
      // string in this format at registration time.
      const path = (source as string).replace(/^@outletArgs\./, "");
      return getByPath(context?.outletArgs, path);
    }

    return undefined;
  }

  /**
   * Default source value when `source` parameter is not provided.
   * Override in subclasses to provide a fallback (e.g., currentUser, siteSettings).
   */
  get defaultSource(): unknown {
    return undefined;
  }

  /**
   * Resolves the source value, falling back to defaultSource when not provided.
   *
   * @param args - The condition arguments.
   * @param context - Evaluation context.
   * @returns The resolved source or defaultSource.
   */
  getSourceValue(
    args: Record<string, unknown>,
    context?: ConditionContext
  ): unknown {
    return args.source !== undefined
      ? this.resolveSource(args, context)
      : this.defaultSource;
  }

  /**
   * Evaluates whether the condition passes.
   * Called at render time to determine if a block should be shown.
   *
   * **Note: This method MUST be pure and idempotent.** It may be called
   * multiple times during a single render cycle (e.g., when debug logging
   * is enabled), and should not have side effects.
   *
   * @param args - The condition arguments from the layout entry.
   * @param context - Evaluation context from the blocks service.
   * @returns True if condition passes, false otherwise.
   */
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  evaluate(args: Record<string, unknown>, context?: ConditionContext): boolean {
    throw new Error(`${this.constructor.name} must implement evaluate()`);
  }

  /**
   * Returns the resolved value for debug logging purposes.
   *
   * Override this method in subclasses to provide custom resolved values
   * for conditions that don't use the standard `source` parameter.
   * For example, the `outletArg` condition uses a `path` parameter
   * to resolve values from outlet args.
   *
   * @param args - The condition arguments from the layout entry.
   * @param context - Evaluation context containing outletArgs.
   * @returns Object with resolved value, or undefined if this condition doesn't resolve values.
   */
  getResolvedValueForLogging(
    args: Record<string, unknown>,
    context?: ConditionContext
  ): ConditionResolvedValue | undefined {
    // Default implementation returns resolved source if present
    if (args.source !== undefined) {
      return { value: this.resolveSource(args, context), hasValue: true };
    }
    return undefined;
  }
}
