// @ts-check
/**
 * Block debug logger with styled console output.
 *
 * Provides grouped, hierarchical logging for condition evaluations.
 * Logs are grouped by block, showing condition trees with pass/fail status.
 *
 * This module lives in the dev-tools bundle and is only loaded when dev tools
 * are enabled, reducing the main application bundle size.
 *
 * @module discourse/static/dev-tools/block-debug/debug-logger
 */

import { isTypeMismatch } from "discourse/lib/blocks/matching/value-matcher";

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
   * WeakMap to track pending log entries by condition spec object.
   * This allows updating log entries by reference rather than by depth/type lookup,
   * which is more robust for complex nested conditions.
   *
   * @type {WeakMap<Object, Object>}
   */
  #pendingLogs = new WeakMap();

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
   * @param {{ value: *, hasValue: true, note?: string }|undefined} [options.resolvedValue] - Resolved value object
   * @param {Object} [options.conditionSpec] - The condition spec object, used to track
   *   pending results for combinators/conditions that log before evaluation completes.
   */
  logCondition({
    type,
    args,
    result,
    depth = 0,
    resolvedValue,
    conditionSpec,
  }) {
    if (!this.#currentGroup) {
      this.#logStandalone(type, args, result);
      return;
    }

    const logEntry = { type, args, result, depth, resolvedValue };
    this.#currentGroup.logs.push(logEntry);

    // Track pending logs by conditionSpec for later result updates.
    // This is used for combinators (AND/OR/NOT) and conditions that need to
    // log nested items before knowing their final result.
    if (conditionSpec && result === null) {
      this.#pendingLogs.set(conditionSpec, logEntry);
    }
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
   * Log current URL/page state for debugging route conditions.
   * Shows URL/page matching status. Params and queryParams are logged separately
   * with proper nesting via logCondition.
   *
   * @param {Object} options - Log options.
   * @param {string} options.currentPath - The current URL path (normalized).
   * @param {Array} [options.expectedUrls] - URL patterns to match (if using urls).
   * @param {Array} [options.excludeUrls] - URL patterns to exclude (if using excludeUrls).
   * @param {Array} [options.pages] - Page types to match (e.g., ["CATEGORY_PAGES"]).
   * @param {string} [options.matchedPageType] - The page type that matched (if pages used).
   * @param {string} [options.actualPageType] - The actual page type (when expected doesn't match).
   * @param {Object} [options.actualPageContext] - Actual page context (for determining page type match).
   * @param {number} options.depth - Nesting depth for indentation.
   * @param {boolean} options.result - Whether the URL/page matched (true) or not (false).
   */
  logRouteState({
    currentPath,
    expectedUrls,
    excludeUrls,
    pages,
    matchedPageType,
    actualPageType,
    actualPageContext,
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
      pages,
      matchedPageType,
      actualPageType,
      actualPageContext,
      depth,
      result,
    });
  }

  /**
   * Update the result of a combinator (AND/OR/NOT) by its condition spec.
   * Used to set the actual result after children have been evaluated.
   *
   * @param {Object} conditionSpec - The condition spec object used when logging.
   * @param {boolean} result - The actual result.
   */
  updateCombinatorResult(conditionSpec, result) {
    if (!this.#currentGroup || !conditionSpec) {
      return;
    }

    const logEntry = this.#pendingLogs.get(conditionSpec);
    if (logEntry) {
      logEntry.result = result;
      this.#pendingLogs.delete(conditionSpec);
    }
  }

  /**
   * Update the result of a condition by its condition spec.
   * Used when the condition needs to log nested items before knowing its final result.
   *
   * @param {Object} conditionSpec - The condition spec object used when logging.
   * @param {boolean} result - The actual result.
   */
  updateConditionResult(conditionSpec, result) {
    if (!this.#currentGroup || !conditionSpec) {
      return;
    }

    const logEntry = this.#pendingLogs.get(conditionSpec);
    if (logEntry) {
      logEntry.result = result;
      this.#pendingLogs.delete(conditionSpec);
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
   * @param {{ value: *, hasValue: true, formatted?: Object, note?: string }|undefined} [log.resolvedValue] - Resolved value object.
   * @param {string} [log.currentPath] - Current URL path (for route-state type).
   * @param {Array<string>} [log.expectedUrls] - Expected URL patterns (for route-state type).
   * @param {Array<string>} [log.excludeUrls] - Excluded URL patterns (for route-state type).
   * @param {Object} [log.pages] - Page configuration (for route-state type).
   * @param {string} [log.actualPageType] - Actual page type (for route-state type).
   * @param {Object} [log.actualPageContext] - Actual page context (for route-state type).
   * @param {boolean} [hasChildren=false] - Whether this node has nested children.
   */
  #logTreeNode(log, hasChildren = false) {
    const { type, args, result, resolvedValue } = log;

    // Handle route state (shows current URL/page status)
    // Uses checkmark/X to show whether the route matched
    if (type === "route-state") {
      const {
        currentPath,
        expectedUrls,
        excludeUrls: excludedUrls,
        pages,
        actualPageType,
        actualPageContext,
        result: routeResult,
      } = log;
      const routeIcon = routeResult ? ICONS.passed : ICONS.failed;
      const routeStyle = routeResult ? STYLES.passed : STYLES.failed;

      // When using pages option, show page type and params as siblings
      if (pages) {
        // Page type matches if actualPageContext exists (regardless of params)
        const pageTypeMatched = actualPageContext !== null;
        const pageIcon = pageTypeMatched ? ICONS.passed : ICONS.failed;
        const pageStyle = pageTypeMatched ? STYLES.passed : STYLES.failed;

        let pageStatus;
        if (pageTypeMatched) {
          pageStatus = `on ${actualPageContext?.pageType || pages[0]}`;
        } else {
          // Show what page type they're actually on (if any)
          const actualInfo = actualPageType
            ? ` (actual: ${actualPageType})`
            : "";
          pageStatus = `not on ${pages.join(", ")}${actualInfo}`;
        }

        // eslint-disable-next-line no-console
        console.log(`%c${pageIcon}%c ${pageStatus}`, pageStyle, "");

        // Note: params are logged separately with nesting (like queryParams)
        return;
      }

      // For urls option, show URL matching info
      const expected = excludedUrls
        ? { excludeUrls: excludedUrls }
        : { urls: expectedUrls };

      // eslint-disable-next-line no-console
      console.log(`%c${routeIcon}%c current URL:`, routeStyle, "", {
        actual: currentPath,
        expected,
      });
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
      // Use formatted object if provided, otherwise add actual to args
      const hasResolved = resolvedValue?.hasValue;
      let loggedArgs;
      if (hasResolved && resolvedValue.formatted) {
        loggedArgs = resolvedValue.formatted;
      } else if (hasResolved) {
        loggedArgs =
          args && Object.keys(args).length > 0
            ? { ...args, actual: resolvedValue.value }
            : { actual: resolvedValue.value };
      } else {
        loggedArgs = args && Object.keys(args).length > 0 ? args : "";
      }

      // Display warning note if present (e.g., unknown setting names)
      if (resolvedValue?.note) {
        logFn.call(
          console,
          `%c${icon}%c ${type} %c⚠ ${resolvedValue.note}`,
          iconStyle,
          "",
          STYLES.hint,
          loggedArgs
        );
      } else {
        logFn.call(console, `%c${icon}%c ${type}`, iconStyle, "", loggedArgs);
      }
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
