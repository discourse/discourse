/**
 * Block debug logger with styled console output.
 *
 * Provides grouped, hierarchical logging for condition evaluations.
 * Logs are grouped by block, showing condition trees with pass/fail status.
 *
 * @module discourse/lib/blocks/debug-logger
 */

import { isTypeMismatch } from "./value-matcher";

// Console output styles
const STYLES = {
  blockName: "font-weight: bold", // bold only, no color
  passed: "color: #50c050; font-weight: bold", // bright green for RENDERED
  failed: "color: #e05050; font-weight: bold", // vivid red for SKIPPED
  combinator: "color: #3070c0; font-weight: bold", // bold blue for operators
  hint: "color: #d4a000; font-style: italic", // yellow/orange for hints
};

const ICONS = {
  passed: "\u2713", // checkmark
  failed: "\u2717", // X (failed)
};

/**
 * Block debug logger class.
 * Provides grouped console output for block condition evaluations.
 */
class BlockDebugLogger {
  /**
   * Current evaluation group context.
   *
   * @type {{blockName: string, hierarchy: string, logs: Array}|null}
   */
  #currentGroup = null;

  /**
   * Start a new evaluation group for a block render.
   * All subsequent logCondition calls will be collected in this group
   * until endGroup is called.
   *
   * @param {string} blockName - The block being evaluated
   * @param {string} hierarchy - The outlet/parent hierarchy path (e.g., "outlet-name/parent-block")
   */
  startGroup(blockName, hierarchy) {
    this.#currentGroup = { blockName, hierarchy, logs: [] };
  }

  /**
   * Log a condition evaluation within the current group.
   * If no group is active, logs immediately to console.
   *
   * @param {Object} options - Log options
   * @param {string} options.type - Condition type or combinator (AND/OR/NOT)
   * @param {Object} [options.args] - Condition arguments
   * @param {boolean} options.result - Whether condition passed
   * @param {number} [options.depth=0] - Nesting depth for indentation
   */
  logCondition({ type, args, result, depth = 0 }) {
    if (!this.#currentGroup) {
      this.#logStandalone(type, args, result);
      return;
    }

    this.#currentGroup.logs.push({ type, args, result, depth });
  }

  /**
   * Log a param group with all matches as a nested expandable group.
   * Used for params/queryParams matching in route conditions.
   *
   * @param {Object} options - Log options.
   * @param {string} options.label - Group label ("params" or "queryParams").
   * @param {Array<{key: string, expected: *, actual: *, result: boolean}>} options.matches - Match results.
   * @param {boolean} options.result - Overall result (all passed).
   * @param {number} options.depth - Nesting depth for indentation.
   */
  logParamGroup({ label, matches, result, depth }) {
    if (!this.#currentGroup) {
      return;
    }
    this.#currentGroup.logs.push({
      type: "param-group",
      label,
      matches,
      result,
      depth,
    });
  }

  /**
   * Log current URL state for debugging route conditions with params/queryParams.
   * Shows the actual values available for matching.
   *
   * @param {Object} options - Log options.
   * @param {string} options.currentPath - The current URL path (normalized).
   * @param {Array} [options.expectedUrls] - URL patterns to match (if using urls).
   * @param {Array} [options.excludeUrls] - URL patterns to exclude (if using excludeUrls).
   * @param {Object} options.actualParams - Current route params.
   * @param {Object} options.actualQueryParams - Current query params.
   * @param {number} options.depth - Nesting depth for indentation.
   * @param {boolean} options.result - Whether the URL matched (true) or not (false).
   */
  logRouteState({
    currentPath,
    expectedUrls,
    excludeUrls,
    actualParams,
    actualQueryParams,
    depth,
    result,
  }) {
    if (!this.#currentGroup) {
      return;
    }
    this.#currentGroup.logs.push({
      type: "route-state",
      currentPath,
      expectedUrls,
      excludeUrls,
      actualParams,
      actualQueryParams,
      depth,
      result,
    });
  }

  /**
   * Update the result of the last combinator (AND/OR/NOT) at the given depth.
   * Used to set the actual result after children have been evaluated.
   *
   * @param {boolean} result - The actual result
   * @param {number} depth - The depth of the combinator to update
   */
  updateCombinatorResult(result, depth) {
    if (!this.#currentGroup) {
      return;
    }

    // Find the combinator at this depth (should be before its children)
    for (const log of this.#currentGroup.logs) {
      if (
        log.depth === depth &&
        ["AND", "OR", "NOT"].includes(log.type) &&
        log.result === null
      ) {
        log.result = result;
        break;
      }
    }
  }

  /**
   * Update the result of the last condition of a given type at a given depth.
   * Used when the condition needs to log nested items before knowing its final result.
   *
   * @param {string} type - The condition type to update
   * @param {boolean} result - The actual result
   * @param {number} depth - The depth of the condition to update
   */
  updateConditionResult(type, result, depth) {
    if (!this.#currentGroup) {
      return;
    }

    // Find the condition at this depth with matching type and null result
    for (const log of this.#currentGroup.logs) {
      if (log.depth === depth && log.type === type && log.result === null) {
        log.result = result;
        break;
      }
    }
  }

  /**
   * End the current group and flush logs to console.
   * Uses console.groupCollapsed for a clean, expandable view.
   * Conditions with nested children are rendered as collapsible groups.
   *
   * @param {boolean} finalResult - Whether the block will render
   */
  endGroup(finalResult) {
    if (!this.#currentGroup) {
      return;
    }

    const { blockName, hierarchy, logs } = this.#currentGroup;

    if (logs.length === 0) {
      this.#currentGroup = null;
      return;
    }

    const status = finalResult ? "RENDERED" : "SKIPPED";
    const statusStyle = finalResult ? STYLES.passed : STYLES.failed;
    const icon = finalResult ? ICONS.passed : ICONS.failed;

    // Format: [Blocks] {icon} {STATUS} {blockName} in {hierarchy}
    // eslint-disable-next-line no-console
    console.groupCollapsed(
      `[Blocks] %c${icon} ${status}%c %c${blockName}%c in ${hierarchy}`,
      statusStyle, // icon + status - same color
      "", // reset
      STYLES.blockName, // block name - bold
      "font-weight: normal" // "in {hierarchy}" - explicitly reset bold
    );

    // Track open groups by their depth so we can close them when needed
    const openGroupDepths = [];

    for (let i = 0; i < logs.length; i++) {
      const log = logs[i];
      const nextLog = logs[i + 1];

      // Close any groups at same or deeper depth before rendering this log
      while (
        openGroupDepths.length > 0 &&
        openGroupDepths[openGroupDepths.length - 1] >= log.depth
      ) {
        // eslint-disable-next-line no-console
        console.groupEnd();
        openGroupDepths.pop();
      }

      // Check if this log has children (next log is deeper)
      const hasChildren = nextLog && nextLog.depth > log.depth;

      this.#logTreeNode(log, hasChildren);

      // If we opened a group for this log, track it
      if (hasChildren && this.#isGroupableLog(log)) {
        openGroupDepths.push(log.depth);
      }
    }

    // Close any remaining open groups
    while (openGroupDepths.length > 0) {
      // eslint-disable-next-line no-console
      console.groupEnd();
      openGroupDepths.pop();
    }

    // eslint-disable-next-line no-console
    console.groupEnd();
    this.#currentGroup = null;
  }

  /**
   * Check if a log entry should be rendered as a collapsible group when it has children.
   * Param groups and route state handle their own grouping internally.
   *
   * @param {Object} log - The log entry
   * @returns {boolean} True if this log should be a group when it has children
   */
  #isGroupableLog(log) {
    const isSpecialType = ["param-group", "route-state"].includes(log.type);
    return !isSpecialType;
  }

  /**
   * Log a single node in the condition tree.
   *
   * @param {Object} log - The log entry.
   * @param {string} log.type - Condition type.
   * @param {Object} [log.args] - Condition arguments.
   * @param {boolean} log.result - Pass/fail.
   * @param {number} log.depth - Indentation depth.
   * @param {string} [log.label] - Label for param groups.
   * @param {Array} [log.matches] - Match results for param groups.
   * @param {boolean} [hasChildren=false] - Whether this node has nested children.
   */
  #logTreeNode(log, hasChildren = false) {
    const { type, args, result } = log;

    // Handle route state (shows current URL and params/queryParams values)
    // Uses checkmark/X to show whether URL matched
    if (type === "route-state") {
      const {
        currentPath,
        expectedUrls,
        excludeUrls: excludedUrls,
        actualParams,
        actualQueryParams,
        result: routeResult,
      } = log;
      const routeIcon = routeResult ? ICONS.passed : ICONS.failed;
      const routeStyle = routeResult ? STYLES.passed : STYLES.failed;

      // Build configured value based on whether urls or excludeUrls was used
      const configured = excludedUrls
        ? { excludeUrls: excludedUrls }
        : expectedUrls;

      // eslint-disable-next-line no-console
      console.groupCollapsed(`%c${routeIcon}%c current URL`, routeStyle, "", {
        actual: currentPath,
        configured,
      });
      if (actualParams && Object.keys(actualParams).length > 0) {
        // eslint-disable-next-line no-console
        console.log("params:", actualParams);
      }
      if (actualQueryParams && Object.keys(actualQueryParams).length > 0) {
        // eslint-disable-next-line no-console
        console.log("queryParams:", actualQueryParams);
      }
      // eslint-disable-next-line no-console
      console.groupEnd();
      return;
    }

    const icon = result ? ICONS.passed : ICONS.failed;
    const iconStyle = result ? STYLES.passed : STYLES.failed;

    // Handle param group (params/queryParams)
    if (type === "param-group") {
      const { label, matches } = log;

      // Single key: print directly without group wrapper
      if (matches.length === 1) {
        const match = matches[0];
        this.#logParamMatch(match, `${label}: ${match.key}`, icon, iconStyle);
        return;
      }

      // Multiple keys: use collapsible group
      // eslint-disable-next-line no-console
      console.groupCollapsed(
        `%c${icon}%c ${label} (${matches.length} keys)`,
        iconStyle,
        ""
      );

      for (const match of matches) {
        const matchIcon = match.result ? ICONS.passed : ICONS.failed;
        const matchStyle = match.result ? STYLES.passed : STYLES.failed;
        this.#logParamMatch(match, match.key, matchIcon, matchStyle);
      }

      // eslint-disable-next-line no-console
      console.groupEnd();
      return;
    }

    const isCombinator = ["AND", "OR", "NOT"].includes(type);

    // Use groupCollapsed for conditions with children, log for others
    // eslint-disable-next-line no-console
    const logFn = hasChildren ? console.groupCollapsed : console.log;

    if (isCombinator) {
      logFn.call(
        console,
        `%c${icon}%c %c${type}`,
        iconStyle,
        "",
        STYLES.combinator,
        args ? `(${args})` : ""
      );
    } else {
      // Condition type has no special formatting
      logFn.call(
        console,
        `%c${icon}%c ${type}`,
        iconStyle,
        "",
        args && Object.keys(args).length > 0 ? args : ""
      );
    }
  }

  /**
   * Log a single param match with optional type mismatch hint.
   *
   * @param {Object} match - The match object with configured (expected), actual, result.
   * @param {string} label - Display label for the param.
   * @param {string} icon - Pass/fail icon.
   * @param {string} iconStyle - CSS style for the icon.
   */
  #logParamMatch(match, label, icon, iconStyle) {
    const { expected: configured, actual, result } = match;

    // Check for type mismatch on failed matches
    if (!result && isTypeMismatch(actual, configured)) {
      const configuredType = this.#getExpectedValueType(configured);
      // eslint-disable-next-line no-console
      console.log(
        `%c${icon}%c ${label} %c⚠ type mismatch: actual is ${typeof actual}, condition specifies ${configuredType}`,
        iconStyle,
        "",
        STYLES.hint,
        { actual, configured }
      );
      return;
    }

    // eslint-disable-next-line no-console
    console.log(`%c${icon}%c ${label}`, iconStyle, "", { actual, configured });
  }

  /**
   * Get the type of value configured in the condition, unwrapping `{ any: [...] }` and arrays.
   * Shows all unique types if mixed (e.g., "number/string").
   *
   * @param {*} expected - The configured value spec from the condition.
   * @returns {string} The type description.
   */
  #getExpectedValueType(expected) {
    // Unwrap { any: [...] } or arrays
    const values = expected?.any ?? (Array.isArray(expected) ? expected : null);

    if (values && values.length > 0) {
      const types = [...new Set(values.map((v) => typeof v))];
      return types.join("/");
    }

    return typeof expected;
  }

  /**
   * Log a standalone condition (when no group is active).
   *
   * @param {string} type - Condition type
   * @param {Object} args - Condition arguments
   * @param {boolean} result - Pass/fail
   */
  #logStandalone(type, args, result) {
    const icon = result ? ICONS.passed : ICONS.failed;
    // eslint-disable-next-line no-console
    console.debug(`[Blocks] ${icon} ${type}:`, args);
  }

  /**
   * Log that an optional block was skipped because it's not registered.
   * Uses standalone log (no group needed since there are no conditions to show).
   * Format matches endGroup header: `[Blocks] ✗ SKIPPED {blockName} in {hierarchy}`
   *
   * @param {string} blockName - The name of the missing optional block.
   * @param {string} hierarchy - The outlet/container hierarchy path.
   */
  logOptionalMissing(blockName, hierarchy) {
    // eslint-disable-next-line no-console
    console.log(
      `[Blocks] %c${ICONS.failed} SKIPPED%c %c${blockName}%c in ${hierarchy} %c(optional, not registered)`,
      STYLES.failed,
      "",
      STYLES.blockName,
      "font-weight: normal",
      STYLES.hint
    );
  }

  /**
   * Check if a group is currently active.
   *
   * @returns {boolean}
   */
  hasActiveGroup() {
    return this.#currentGroup !== null;
  }
}

export const blockDebugLogger = new BlockDebugLogger();
