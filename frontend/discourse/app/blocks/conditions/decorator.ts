import type { ArgSchema, BlockConstraints } from "discourse/blocks/types";
import {
  MAX_BLOCK_NAME_LENGTH,
  parseBlockName,
  type ParsedBlockName,
  VALID_NAMESPACED_BLOCK_PATTERN,
} from "discourse/lib/blocks/-internals/patterns";
import { validateConditionArgsSchema } from "discourse/lib/blocks/-internals/validation/condition-args";
import { validateConstraintsSchema } from "discourse/lib/blocks/-internals/validation/constraints";
import { formatWithSuggestion } from "discourse/lib/string-similarity";
import {
  BlockCondition,
  type ConditionSourceType,
  type ConditionValidateFn,
} from "./condition";

/**
 * Valid sourceType values for the decorator config.
 */
const VALID_SOURCE_TYPES: readonly ConditionSourceType[] = Object.freeze([
  "none",
  "outletArgs",
  "object",
]);

/**
 * Valid config keys for the decorator.
 */
const VALID_CONFIG_KEYS: readonly string[] = Object.freeze([
  "type",
  "sourceType",
  "args",
  "constraints",
  "validate",
  "displayName",
  "description",
]);

/**
 * WeakSet tracking decorated classes.
 * Private - only accessible via isDecoratedCondition().
 */
const decoratedConditions = new WeakSet<object>();

/**
 * Checks if a class was decorated with `@blockCondition`.
 * Used by the block registration system to reject non-decorated classes.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param ConditionClass - The class to check. Widened to `object` (rather than
 *   a condition-class type) because this is also probed defensively before a
 *   class is known to extend `BlockCondition`.
 * @returns True if the class was decorated.
 */
export function isDecoratedCondition(ConditionClass: object): boolean {
  return decoratedConditions.has(ConditionClass);
}

/** Configuration accepted by the `@blockCondition` decorator. */
export interface BlockConditionConfig {
  /** Unique condition type identifier. */
  type: string;

  /** How the `source` parameter is handled. Defaults to `"none"`. */
  sourceType?: ConditionSourceType;

  /** Arg schema definitions (type, required, min, max, pattern, etc.).
   *  Use `{ type: "any" }` to allow any type. */
  args?: Record<string, ArgSchema>;

  /** Cross-arg constraints (atLeastOne, exactlyOne, allOrNone, atMostOne). */
  constraints?: BlockConstraints;

  /** Custom validation function called at registration time. Receives the
   *  args object, returns an error string/array or null. */
  validate?: ConditionValidateFn;

  /** Human-readable label for display purposes. Falls back to a titleCased
   *  `type` when omitted. */
  displayName?: string;

  /** Short human-readable description. No description is shown when omitted. */
  description?: string;
}

/**
 * Decorator to define a block condition with declarative arg validation.
 *
 * The class must extend BlockCondition. The decorator adds static getters
 * for type, sourceType, argsSchema, constraints, validateFn, and validArgKeys
 * based on the provided config. Unknown config keys are rejected with helpful suggestions.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param config - Condition configuration; see {@link BlockConditionConfig}
 *   for the individual fields.
 * @throws Error If config is invalid or class doesn't extend BlockCondition.
 *
 * @example
 * ```javascript
 * import { blockCondition, BlockCondition } from "discourse/blocks/conditions";
 *
 * @blockCondition({
 *   type: "user",
 *   sourceType: "outletArgs",
 *   args: {
 *     loggedIn: { type: "boolean" },
 *     admin: { type: "boolean" },
 *     minTrustLevel: { type: "number", min: 0, max: 4, integer: true },
 *     groups: { type: "array", itemType: "string" },
 *   },
 *   validate(args) {
 *     if (args.loggedIn === false && args.admin) {
 *       return "Cannot use loggedIn: false with admin condition.";
 *     }
 *     return null;
 *   }
 * })
 * export default class BlockUserCondition extends BlockCondition {
 *   @service currentUser;
 *   evaluate(args, context) { ... }
 * }
 * ```
 *
 * @example
 * ```javascript
 * // With constraints
 * @blockCondition({
 *   type: "setting",
 *   sourceType: "object",
 *   args: {
 *     name: { type: "string", required: true },
 *     enabled: { type: "boolean" },
 *     equals: { type: "any" },
 *     includes: { type: "array" },
 *   },
 *   constraints: {
 *     atMostOne: ["enabled", "equals", "includes"],
 *   },
 * })
 * ```
 */
export function blockCondition(config: BlockConditionConfig): ClassDecorator {
  const {
    type,
    sourceType = "none",
    args: argsSchema = {},
    constraints,
    validate: validateFn,
    displayName,
    description,
  } = config;

  // Validate config at decoration time
  if (!type || typeof type !== "string") {
    throw new Error("blockCondition: `type` is required and must be a string.");
  }

  // Validate type length
  if (type.length > MAX_BLOCK_NAME_LENGTH) {
    throw new Error(
      `blockCondition: type "${type}" exceeds maximum length of ${MAX_BLOCK_NAME_LENGTH} characters.`
    );
  }

  // Validate type follows the namespaced pattern
  if (!VALID_NAMESPACED_BLOCK_PATTERN.test(type)) {
    throw new Error(
      `blockCondition: type "${type}" is invalid. ` +
        `Valid formats: "condition-name" (core), "plugin:condition-name" (plugin), ` +
        `"theme:namespace:condition-name" (theme).`
    );
  }

  // Parse the type to extract namespace components. `type` is regex-validated
  // above, so `parseBlockName` is guaranteed to resolve one of its three
  // namespace formats and never return null here.
  const parsed = parseBlockName(type) as ParsedBlockName;

  // Validate sourceType is one of the allowed values
  if (!VALID_SOURCE_TYPES.includes(sourceType)) {
    const suggestion = formatWithSuggestion(sourceType, VALID_SOURCE_TYPES);
    throw new Error(
      `blockCondition: Invalid \`sourceType\` ${suggestion}. ` +
        `Valid values are: ${VALID_SOURCE_TYPES.join(", ")}.`
    );
  }

  // Validate no unknown config keys (catches typos)
  const unknownKeys = Object.keys(config).filter(
    (key) => !VALID_CONFIG_KEYS.includes(key)
  );
  if (unknownKeys.length > 0) {
    const suggestions = unknownKeys
      .map((key) => formatWithSuggestion(key, VALID_CONFIG_KEYS))
      .join(", ");
    throw new Error(
      `blockCondition: unknown config key(s): ${suggestions}. ` +
        `Valid keys are: ${VALID_CONFIG_KEYS.join(", ")}.`
    );
  }

  // Validate args schema at decoration time (catches schema definition errors)
  if (argsSchema && typeof argsSchema === "object") {
    validateConditionArgsSchema(argsSchema, type);
  }

  // Validate constraints schema at decoration time
  if (constraints) {
    // Constraints reference args schema - validate they're compatible
    validateConstraintsSchema(constraints, argsSchema, `Condition "${type}"`);
  }

  // Validate that validate is a function if provided
  if (validateFn !== undefined && typeof validateFn !== "function") {
    throw new Error(
      `blockCondition: "validate" must be a function, got ${typeof validateFn}.`
    );
  }

  // Shallow type-check the display-metadata fields. These are advisory
  // presentation hints with no runtime effect on evaluation.
  if (
    displayName !== undefined &&
    (typeof displayName !== "string" || displayName.trim() === "")
  ) {
    throw new Error(
      `blockCondition: "displayName" must be a non-empty string.`
    );
  }
  if (description !== undefined && typeof description !== "string") {
    throw new Error(`blockCondition: "description" must be a string.`);
  }

  // Freeze schema and compute derived validArgKeys
  const frozenSchema: Readonly<Record<string, ArgSchema>> = Object.freeze({
    ...argsSchema,
  });
  const frozenConstraints: Readonly<BlockConstraints> | undefined = constraints
    ? Object.freeze({ ...constraints })
    : undefined;
  const argKeys: readonly string[] = Object.freeze(Object.keys(argsSchema));
  const allKeys: readonly string[] =
    sourceType !== "none" ? Object.freeze([...argKeys, "source"]) : argKeys;

  return (TargetClass) => {
    // Validate that the class extends BlockCondition
    if (!(TargetClass.prototype instanceof BlockCondition)) {
      throw new Error(
        `blockCondition: ${TargetClass.name} must extend BlockCondition.`
      );
    }

    // Define static getters (non-configurable to prevent reassignment).
    Object.defineProperties(TargetClass, {
      type: { get: () => type, configurable: false },
      namespace: { get: () => parsed.namespace, configurable: false },
      namespaceType: { get: () => parsed.type, configurable: false },
      sourceType: { get: () => sourceType, configurable: false },
      argsSchema: { get: () => frozenSchema, configurable: false },
      constraints: { get: () => frozenConstraints, configurable: false },
      validateFn: { get: () => validateFn, configurable: false },
      // validArgKeys combines argsSchema keys with "source" when sourceType !== "none".
      validArgKeys: { get: () => allKeys, configurable: false },
      // Advisory display-metadata fields. Both default to `null` so a
      // consumer can fall back to a titleCased `type` or no description.
      displayName: { get: () => displayName ?? null, configurable: false },
      description: { get: () => description ?? null, configurable: false },
    });

    // Track as decorated so Blocks service can verify
    decoratedConditions.add(TargetClass);

    // A legacy class decorator that returns nothing keeps the class
    // unchanged, which is exactly what this decorator wants — it records
    // metadata and tracks the class as decorated as side effects rather than
    // replacing the class, so there is no need to return the target.
  };
}
