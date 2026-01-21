// @ts-check
import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/debug/block-processing";

/**
 * Evaluates condition specs at render time.
 * Recursively evaluates nested conditions with AND/OR/NOT logic.
 *
 * @param {Object|Array<Object>} conditionSpec - Condition spec(s) to evaluate.
 * @param {Map<string, import("discourse/blocks/conditions").BlockCondition>} conditionTypes - Map of registered condition types.
 * @param {Object} [context] - Evaluation context.
 * @param {boolean} [context.debug] - Enable debug logging for this evaluation.
 * @param {number} [context._depth] - Internal: nesting depth for logging.
 * @param {Object} [context.outletArgs] - Outlet arguments passed to conditions.
 * @returns {boolean} True if conditions pass, false otherwise.
 */
export function evaluateConditions(
  conditionSpec,
  conditionTypes,
  context = {}
) {
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
  if (conditionSpec.any !== undefined) {
    return evaluateOrCombinator(
      conditionSpec,
      conditionTypes,
      context,
      isLoggingEnabled,
      depth,
      conditionLog,
      combinatorLog
    );
  }

  // NOT combinator (must fail)
  if (conditionSpec.not !== undefined) {
    return evaluateNotCombinator(
      conditionSpec,
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
    conditionSpec,
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
 * @param {Array<Object>} conditionSpec - Array of condition specs.
 * @param {Map} conditionTypes - Map of registered condition types.
 * @param {Object} context - Evaluation context.
 * @param {boolean} isLoggingEnabled - Whether debug logging is enabled.
 * @param {number} depth - Current nesting depth.
 * @param {Function|null} conditionLog - Callback for logging conditions.
 * @param {Function|null} combinatorLog - Callback for logging combinator results.
 * @returns {boolean} True if all conditions pass.
 */
function evaluateAndCombinator(
  conditionSpec,
  conditionTypes,
  context,
  isLoggingEnabled,
  depth,
  conditionLog,
  combinatorLog
) {
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
 * @param {Object} conditionSpec - Condition spec containing "any" array.
 * @param {Map} conditionTypes - Map of registered condition types.
 * @param {Object} context - Evaluation context.
 * @param {boolean} isLoggingEnabled - Whether debug logging is enabled.
 * @param {number} depth - Current nesting depth.
 * @param {Function|null} conditionLog - Callback for logging conditions.
 * @param {Function|null} combinatorLog - Callback for logging combinator results.
 * @returns {boolean} True if at least one condition passes.
 */
function evaluateOrCombinator(
  conditionSpec,
  conditionTypes,
  context,
  isLoggingEnabled,
  depth,
  conditionLog,
  combinatorLog
) {
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
 * @param {Object} conditionSpec - Condition spec containing "not" condition.
 * @param {Map} conditionTypes - Map of registered condition types.
 * @param {Object} context - Evaluation context.
 * @param {boolean} isLoggingEnabled - Whether debug logging is enabled.
 * @param {number} depth - Current nesting depth.
 * @param {Function|null} conditionLog - Callback for logging conditions.
 * @param {Function|null} combinatorLog - Callback for logging combinator results.
 * @returns {boolean} True if inner condition fails.
 */
function evaluateNotCombinator(
  conditionSpec,
  conditionTypes,
  context,
  isLoggingEnabled,
  depth,
  conditionLog,
  combinatorLog
) {
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
 * @param {Object} conditionSpec - Single condition spec with type.
 * @param {Map} conditionTypes - Map of registered condition types.
 * @param {Object} context - Evaluation context.
 * @param {boolean} isLoggingEnabled - Whether debug logging is enabled.
 * @param {number} depth - Current nesting depth.
 * @param {Function|null} conditionLog - Callback for logging conditions.
 * @param {Function|null} conditionResultLog - Callback for logging condition results.
 * @param {Object|null} logger - Logger interface for conditions.
 * @returns {boolean} True if condition passes.
 */
function evaluateSingleCondition(
  conditionSpec,
  conditionTypes,
  context,
  isLoggingEnabled,
  depth,
  conditionLog,
  conditionResultLog,
  logger
) {
  const { type, ...args } = conditionSpec;
  const conditionInstance = conditionTypes.get(type);

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
