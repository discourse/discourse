/**
 * Block debug logger with styled console output.
 *
 * Provides grouped, hierarchical logging for condition evaluations.
 * Logs are grouped by block, showing condition trees with pass/fail status.
 *
 * This module lives in the dev-tools bundle and is only loaded when dev tools
 * are enabled, reducing the main application bundle size.
 */

import type { ConditionResolvedValue } from "discourse/blocks/conditions/condition";
import { isTypeMismatch } from "discourse/lib/blocks/-internals/matching/value-matcher";

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

/** A single match result within a param/queryParam group (see `logParamGroup()`). */
export interface ParamMatch {
  /** The param/queryParam key. */
  key: string;
  /** The configured (expected) value spec. */
  expected: unknown;
  /** The actual value from the current route. */
  actual: unknown;
  /** Whether this key matched. */
  result: boolean;
}

/** Options accepted by `logCondition()`. */
export interface LogConditionOptions {
  /** Condition type or combinator (AND/OR/NOT). */
  type: string;
  /** Condition arguments: a record for a leaf condition, a display string for
   *  a combinator (e.g. "3 conditions"), or `null`/omitted for a NOT combinator. */
  args?: string | Record<string, unknown> | null;
  /** Whether condition passed, or `null` for pending combinators. */
  result: boolean | null;
  /** Nesting depth for indentation. */
  depth?: number;
  /** Resolved value object, for conditions that resolve a value. */
  resolvedValue?: ConditionResolvedValue;
  /** The condition spec object, used to track pending results for
   *  combinators/conditions that log before evaluation completes. */
  conditionSpec?: object;
}

/** Options accepted by `logParamGroup()`. */
export interface LogParamGroupOptions {
  /** Group label (e.g., "params", "queryParams", "params[0]"). */
  label: string;
  /** Match results. */
  matches: ParamMatch[];
  /** Overall result (all passed). */
  result: boolean;
  /** Nesting depth for indentation. */
  depth: number;
}

/** Options accepted by `logRouteState()`. */
export interface LogRouteStateOptions {
  /** The current URL path (normalized). */
  currentPath: string;
  /** URL patterns to match (if using urls). */
  expectedUrls?: string[];
  /** URL patterns to exclude (if using excludeUrls). */
  excludeUrls?: string[];
  /** Page types to match (e.g., ["CATEGORY_PAGES"]). */
  pages?: string[];
  /** The actual page type (when expected doesn't match). */
  actualPageType?: string | null;
  /** Actual page context (for determining page type match). */
  actualPageContext?: Record<string, unknown> | null;
  /** Nesting depth for indentation. */
  depth: number;
  /** Whether the URL/page matched (true) or not (false). */
  result: boolean;
}

/** A logged condition/combinator entry within a group's log buffer. */
interface ConditionLogEntry {
  type: string;
  args?: string | Record<string, unknown> | null;
  result: boolean | null;
  depth: number;
  resolvedValue?: ConditionResolvedValue;
}

/** A logged param-group entry, as pushed by `logParamGroup()`. */
interface ParamGroupLogEntry extends LogParamGroupOptions {
  type: "param-group";
}

/** A logged route-state entry, as pushed by `logRouteState()`. */
interface RouteStateLogEntry extends LogRouteStateOptions {
  type: "route-state";
}

/** A single entry in a group's log buffer. */
type DebugLogEntry =
  | ConditionLogEntry
  | ParamGroupLogEntry
  | RouteStateLogEntry;

/** The active evaluation group being built up between `startGroup()` and `endGroup()`. */
interface DebugLogGroup {
  blockName: string;
  blockId: string | null;
  hierarchy: string;
  logs: DebugLogEntry[];
}

/**
 * Block debug logger class.
 * Provides grouped console output for block condition evaluations.
 */
class BlockDebugLogger {
  /**
   * Current evaluation group context.
   */
  #currentGroup: DebugLogGroup | null = null;

  /**
   * WeakMap to track pending log entries by condition spec object.
   * This allows updating log entries by reference rather than by depth/type lookup,
   * which is more robust for complex nested conditions.
   */
  #pendingLogs = new WeakMap<object, ConditionLogEntry>();

  /**
   * Start a new evaluation group for a block render.
   * All subsequent logCondition calls will be collected in this group
   * until endGroup is called.
   *
   * @param blockName - The block being evaluated.
   * @param blockId - The block's unique ID, or null if not set.
   * @param hierarchy - The outlet/parent hierarchy path (e.g., "outlet-name/parent-block").
   */
  startGroup(
    blockName: string,
    blockId: string | null,
    hierarchy: string
  ): void {
    this.#currentGroup = { blockName, blockId, hierarchy, logs: [] };
  }

  /**
   * Log a condition evaluation within the current group.
   * If no group is active, logs immediately to console.
   */
  logCondition({
    type,
    args,
    result,
    depth = 0,
    resolvedValue,
    conditionSpec,
  }: LogConditionOptions): void {
    if (!this.#currentGroup) {
      this.#logStandalone(type, args, result);
      return;
    }

    const logEntry: ConditionLogEntry = {
      type,
      args,
      result,
      depth,
      resolvedValue,
    };
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
   */
  logParamGroup({ label, matches, result, depth }: LogParamGroupOptions): void {
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
   */
  logRouteState(options: LogRouteStateOptions): void {
    if (!this.#currentGroup) {
      return;
    }
    this.#currentGroup.logs.push({ type: "route-state", ...options });
  }

  /**
   * Update the result of a combinator (AND/OR/NOT) by its condition spec.
   * Used to set the actual result after children have been evaluated.
   *
   * @param conditionSpec - The condition spec object used when logging.
   * @param result - The actual result.
   */
  updateCombinatorResult(
    conditionSpec: object | null | undefined,
    result: boolean
  ): void {
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
   * @param conditionSpec - The condition spec object used when logging.
   * @param result - The actual result.
   */
  updateConditionResult(
    conditionSpec: object | null | undefined,
    result: boolean
  ): void {
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
   * @param finalResult - Whether the block will render
   */
  endGroup(finalResult: boolean): void {
    if (!this.#currentGroup) {
      return;
    }

    const { blockName, hierarchy, blockId, logs } = this.#currentGroup;

    if (logs.length === 0) {
      this.#currentGroup = null;
      return;
    }

    const status = finalResult ? "RENDERED" : "SKIPPED";
    const statusStyle = finalResult ? STYLES.passed : STYLES.failed;
    const icon = finalResult ? ICONS.passed : ICONS.failed;

    // Format display name with ID if available: "blockName" or "blockName(#id)"
    const displayName = blockId ? `${blockName}(#${blockId})` : blockName;

    // Format: [Blocks] {icon} {STATUS} {displayName} in {hierarchy}
    // eslint-disable-next-line no-console
    console.groupCollapsed(
      `[Blocks] %c${icon} ${status}%c %c${displayName}%c in ${hierarchy}`,
      statusStyle, // icon + status - same color
      "", // reset
      STYLES.blockName, // block name - bold
      "font-weight: normal" // "in {hierarchy}" - explicitly reset bold
    );

    // Track open groups by their depth so we can close them when needed
    const openGroupDepths: number[] = [];

    for (let i = 0; i < logs.length; i++) {
      const log = logs[i];
      const nextLog: DebugLogEntry | undefined = logs[i + 1];

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
      const hasChildren = !!nextLog && nextLog.depth > log.depth;

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
   * @returns True if this log should be a group when it has children
   */
  #isGroupableLog(log: DebugLogEntry): boolean {
    const isSpecialType = ["param-group", "route-state"].includes(log.type);
    return !isSpecialType;
  }

  /**
   * Log a single node in the condition tree.
   */
  #logTreeNode(log: DebugLogEntry, hasChildren = false): void {
    // Handle route state (shows current URL/page status)
    // Uses checkmark/X to show whether the route matched
    if (log.type === "route-state") {
      // `type` distinguishes the union members at runtime, but is typed as a
      // plain `string` on `ConditionLogEntry`, so it can't discriminate the
      // union for the type-checker — narrow explicitly.
      const routeLog = log as RouteStateLogEntry;
      const {
        currentPath,
        expectedUrls,
        excludeUrls: excludedUrls,
        pages,
        actualPageType,
        actualPageContext,
        result: routeResult,
      } = routeLog;
      const routeIcon = routeResult ? ICONS.passed : ICONS.failed;
      const routeStyle = routeResult ? STYLES.passed : STYLES.failed;

      // When using pages option, show page type and params as siblings
      if (pages) {
        // Page type matches if actualPageContext exists (regardless of params)
        const pageTypeMatched = actualPageContext != null;
        const pageIcon = pageTypeMatched ? ICONS.passed : ICONS.failed;
        const pageStyle = pageTypeMatched ? STYLES.passed : STYLES.failed;

        let pageStatus: string;
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

    // Handle param group (params/queryParams). Same discrimination note as above.
    if (log.type === "param-group") {
      const paramLog = log as ParamGroupLogEntry;
      const { label, matches, result } = paramLog;
      const icon = result ? ICONS.passed : ICONS.failed;
      const iconStyle = result ? STYLES.passed : STYLES.failed;

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

    // Remaining case: a condition or combinator (AND/OR/NOT) entry.
    const conditionLog = log as ConditionLogEntry;
    const { type, args, result, resolvedValue } = conditionLog;

    const icon = result ? ICONS.passed : ICONS.failed;
    const iconStyle = result ? STYLES.passed : STYLES.failed;

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
      // Condition type has no special formatting. `args` is always a record
      // (or absent) here — a combinator's string/null `args` was handled above.
      const argsRecord = args as Record<string, unknown> | null | undefined;

      // Use formatted object if provided, otherwise add actual to args
      const hasResolved = resolvedValue?.hasValue;
      let loggedArgs: unknown;
      if (hasResolved && resolvedValue?.formatted) {
        loggedArgs = resolvedValue.formatted;
      } else if (hasResolved) {
        loggedArgs =
          argsRecord && Object.keys(argsRecord).length > 0
            ? { ...argsRecord, actual: resolvedValue?.value }
            : { actual: resolvedValue?.value };
      } else {
        loggedArgs =
          argsRecord && Object.keys(argsRecord).length > 0 ? argsRecord : "";
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
   * @param match - The match object with configured (expected), actual, result.
   * @param label - Display label for the param.
   * @param icon - Pass/fail icon.
   * @param iconStyle - CSS style for the icon.
   */
  #logParamMatch(
    match: ParamMatch,
    label: string,
    icon: string,
    iconStyle: string
  ): void {
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
   * @returns The type description.
   */
  #getExpectedValueType(expected: unknown): string {
    // Unwrap { any: [...] } or arrays
    const values =
      (expected as { any?: unknown[] } | null)?.any ??
      (Array.isArray(expected) ? expected : null);

    if (values && values.length > 0) {
      const types = [...new Set(values.map((v) => typeof v))];
      return types.join("/");
    }

    return typeof expected;
  }

  /**
   * Log a standalone condition (when no group is active).
   */
  #logStandalone(
    type: string,
    args: string | Record<string, unknown> | null | undefined,
    result: boolean | null
  ): void {
    const icon = result ? ICONS.passed : ICONS.failed;
    // eslint-disable-next-line no-console
    console.debug(`[Blocks] ${icon} ${type}:`, args);
  }

  /**
   * Log that an optional block was skipped because it's not registered.
   * Uses standalone log (no group needed since there are no conditions to show).
   * Format matches endGroup header: `[Blocks] ✗ SKIPPED {displayName} in {hierarchy}`
   *
   * @param blockName - The name of the missing optional block.
   * @param blockId - The block's unique ID, or null if not set.
   * @param hierarchy - The outlet/container hierarchy path.
   */
  logOptionalMissing(
    blockName: string,
    blockId: string | null,
    hierarchy: string
  ): void {
    // Format display name with ID if available
    const displayName = blockId ? `${blockName}(#${blockId})` : blockName;

    // eslint-disable-next-line no-console
    console.log(
      `[Blocks] %c${ICONS.failed} SKIPPED%c %c${displayName}%c in ${hierarchy} %c(optional, not registered)`,
      STYLES.failed,
      "",
      STYLES.blockName,
      "font-weight: normal",
      STYLES.hint
    );
  }

  /**
   * Check if a group is currently active.
   */
  hasActiveGroup(): boolean {
    return this.#currentGroup !== null;
  }
}

export const blockDebugLogger = new BlockDebugLogger();
