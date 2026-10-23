import type { BlockCondition } from "discourse/blocks/conditions";
import {
  DEBUG_CALLBACK,
  type DebugCallback,
  debugHooks,
  type DebugLoggerInterface,
} from "discourse/lib/blocks/-internals/debug-hooks";

/**
 * Evaluation context passed through `evaluateConditions()` and its
 * combinator helpers.
 */
export interface ConditionEvaluationContext {
  /** Enable debug logging for this evaluation. */
  debug?: boolean;
  /** Internal: nesting depth for logging. */
  _depth?: number;
  /** Outlet arguments passed to conditions. */
  outletArgs?: Record<string, unknown>;
}

/**
 * Evaluates condition specs at render time.
 * Recursively evaluates nested conditions with AND/OR/NOT logic.
 *
 * @param conditionSpec - Condition spec(s) to evaluate.
 * @param conditionTypes - Map of registered condition types.
 * @param context - Evaluation context.
 * @returns True if conditions pass, false otherwise.
 */
export function evaluateConditions(
  conditionSpec: unknown,
  conditionTypes: Map<string, BlockCondition>,
  context: ConditionEvaluationContext = {}
): boolean {
  const isLoggingEnabled = context.debug ?? false;
  const depth = context._depth ?? 0;

  // Get logging callbacks (null if dev tools not loaded or logging disabled)
  const conditionLog = isLoggingEnabled
    ? debugHooks.getCallback(DEBUG_CALLBACK.CONDITION_LOG)
    : null;
  const combinatorLog = isLoggingEnabled
    ? debugHooks.getCallback(DEBUG_CALLBACK.COMBINATOR_LOG)
    : null;
  const conditionResultLog = isLoggingEnabled
    ? debugHooks.getCallback(DEBUG_CALLBACK.CONDITION_RESULT)
    : null;
  // Get logger interface for conditions (e.g., route condition needs to log params)
  const logger = isLoggingEnabled ? debugHooks.loggerInterface : null;

  if (!conditionSpec) {
    return true;
  }

  // Array of conditions (AND logic - all must pass)
  if (Array.isArray(conditionSpec)) {
    return evaluateAndCombinator(
      conditionSpec,
      conditionTypes,
      context,
      isLoggingEnabled,
      depth,
      conditionLog,
      combinatorLog
    );
  }

  // OR combinator (at least one must pass)
  if ((conditionSpec as { any?: unknown[] }).any !== undefined) {
    return evaluateOrCombinator(
      conditionSpec as { any: unknown[] },
      conditionTypes,
      context,
      isLoggingEnabled,
      depth,
      conditionLog,
      combinatorLog
    );
  }

  // NOT combinator (must fail)
  if ((conditionSpec as { not?: unknown }).not !== undefined) {
    return evaluateNotCombinator(
      conditionSpec as { not: unknown },
      conditionTypes,
      context,
      isLoggingEnabled,
      depth,
      conditionLog,
      combinatorLog
    );
  }

  // Single condition with type
  return evaluateSingleCondition(
    conditionSpec as { type?: string } & Record<string, unknown>,
    conditionTypes,
    context,
    isLoggingEnabled,
    depth,
    conditionLog,
    conditionResultLog,
    logger
  );
}

/**
 * Evaluates an array of conditions with AND logic (all must pass).
 *
 * @param conditionSpec - Array of condition specs.
 * @param conditionTypes - Map of registered condition types.
 * @param context - Evaluation context.
 * @param isLoggingEnabled - Whether debug logging is enabled.
 * @param depth - Current nesting depth.
 * @param conditionLog - Callback for logging conditions.
 * @param combinatorLog - Callback for logging combinator results.
 * @returns True if all conditions pass.
 */
function evaluateAndCombinator(
  conditionSpec: unknown[],
  conditionTypes: Map<string, BlockCondition>,
  context: ConditionEvaluationContext,
  isLoggingEnabled: boolean,
  depth: number,
  conditionLog: DebugCallback | null | undefined,
  combinatorLog: DebugCallback | null | undefined
): boolean {
  // Empty array is vacuous truth - no conditions to fail
  if (conditionSpec.length === 0) {
    return true;
  }

  // Log combinator BEFORE children (result=null as placeholder)
  conditionLog?.({
    type: "AND",
    args: `${conditionSpec.length} conditions`,
    result: null,
    depth,
    conditionSpec,
  });

  let andResult = true;
  for (const condition of conditionSpec) {
    const result = evaluateConditions(condition, conditionTypes, {
      debug: isLoggingEnabled,
      _depth: depth + 1,
      outletArgs: context.outletArgs,
    });
    if (!result) {
      andResult = false;
      // Short-circuit only when not debugging - evaluate all for debug visibility
      if (!isLoggingEnabled) {
        break;
      }
    }
  }

  // Update combinator with actual result
  combinatorLog?.({ conditionSpec, result: andResult });
  return andResult;
}

/**
 * Evaluates an OR combinator (at least one must pass).
 *
 * @param conditionSpec - Condition spec containing "any" array.
 * @param conditionTypes - Map of registered condition types.
 * @param context - Evaluation context.
 * @param isLoggingEnabled - Whether debug logging is enabled.
 * @param depth - Current nesting depth.
 * @param conditionLog - Callback for logging conditions.
 * @param combinatorLog - Callback for logging combinator results.
 * @returns True if at least one condition passes.
 */
function evaluateOrCombinator(
  conditionSpec: { any: unknown[] },
  conditionTypes: Map<string, BlockCondition>,
  context: ConditionEvaluationContext,
  isLoggingEnabled: boolean,
  depth: number,
  conditionLog: DebugCallback | null | undefined,
  combinatorLog: DebugCallback | null | undefined
): boolean {
  // Empty OR array means no conditions can pass
  if (conditionSpec.any.length === 0) {
    return false;
  }

  // Log combinator BEFORE children (result=null as placeholder)
  conditionLog?.({
    type: "OR",
    args: `${conditionSpec.any.length} conditions`,
    result: null,
    depth,
    conditionSpec,
  });

  let orResult = false;
  for (const condition of conditionSpec.any) {
    const result = evaluateConditions(condition, conditionTypes, {
      debug: isLoggingEnabled,
      _depth: depth + 1,
      outletArgs: context.outletArgs,
    });
    if (result) {
      orResult = true;
      // Short-circuit only when not debugging - evaluate all for debug visibility
      if (!isLoggingEnabled) {
        break;
      }
    }
  }

  // Update combinator with actual result
  combinatorLog?.({ conditionSpec, result: orResult });
  return orResult;
}

/**
 * Evaluates a NOT combinator (inner condition must fail).
 *
 * @param conditionSpec - Condition spec containing "not" condition.
 * @param conditionTypes - Map of registered condition types.
 * @param context - Evaluation context.
 * @param isLoggingEnabled - Whether debug logging is enabled.
 * @param depth - Current nesting depth.
 * @param conditionLog - Callback for logging conditions.
 * @param combinatorLog - Callback for logging combinator results.
 * @returns True if inner condition fails.
 */
function evaluateNotCombinator(
  conditionSpec: { not: unknown },
  conditionTypes: Map<string, BlockCondition>,
  context: ConditionEvaluationContext,
  isLoggingEnabled: boolean,
  depth: number,
  conditionLog: DebugCallback | null | undefined,
  combinatorLog: DebugCallback | null | undefined
): boolean {
  // Log combinator BEFORE children (result=null as placeholder)
  conditionLog?.({
    type: "NOT",
    args: null,
    result: null,
    depth,
    conditionSpec,
  });

  const innerResult = evaluateConditions(conditionSpec.not, conditionTypes, {
    debug: isLoggingEnabled,
    _depth: depth + 1,
    outletArgs: context.outletArgs,
  });
  const notResult = !innerResult;

  // Update combinator with actual result
  combinatorLog?.({ conditionSpec, result: notResult });
  return notResult;
}

/**
 * Evaluates a single condition with a type property.
 *
 * @param conditionSpec - Single condition spec with type.
 * @param conditionTypes - Map of registered condition types.
 * @param context - Evaluation context.
 * @param isLoggingEnabled - Whether debug logging is enabled.
 * @param depth - Current nesting depth.
 * @param conditionLog - Callback for logging conditions.
 * @param conditionResultLog - Callback for logging condition results.
 * @param logger - Logger interface for conditions.
 * @returns True if condition passes.
 */
function evaluateSingleCondition(
  conditionSpec: { type?: string } & Record<string, unknown>,
  conditionTypes: Map<string, BlockCondition>,
  context: ConditionEvaluationContext,
  isLoggingEnabled: boolean,
  depth: number,
  conditionLog: DebugCallback | null | undefined,
  conditionResultLog: DebugCallback | null | undefined,
  logger: DebugLoggerInterface | null
): boolean {
  const { type, ...args } = conditionSpec;
  const conditionInstance = conditionTypes.get(type as string);

  if (!conditionInstance) {
    conditionLog?.({
      type: `unknown "${type}"`,
      args,
      result: false,
      depth,
    });
    return false;
  }

  // Resolve value for logging (handles source, path, and other condition-specific values)
  let resolvedValue;
  if (isLoggingEnabled) {
    resolvedValue = conditionInstance.getResolvedValueForLogging(args, context);
  }

  // Log condition BEFORE evaluate so nested logs appear underneath
  conditionLog?.({
    type,
    args,
    result: null,
    depth,
    resolvedValue,
    conditionSpec,
  });

  // Pass context to evaluate so conditions can access outletArgs and log nested items
  const evalContext = {
    debug: isLoggingEnabled,
    _depth: depth,
    outletArgs: context.outletArgs,
    logger,
  };
  const result = conditionInstance.evaluate(args, evalContext);

  // Update the condition's result after evaluate
  conditionResultLog?.({ conditionSpec, result });
  return result;
}
