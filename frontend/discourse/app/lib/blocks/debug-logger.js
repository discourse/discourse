/**
 * Block debug logger with styled console output.
 *
 * Provides grouped, hierarchical logging for condition evaluations.
 * Logs are grouped by block, showing condition trees with pass/fail status.
 *
 * @module discourse/lib/blocks/debug-logger
 */

// Console output styles
const STYLES = {
  blockName: "font-weight: bold", // bold only, no color
  passed: "color: #50c050; font-weight: bold", // bright green for RENDERED
  failed: "color: #e05050; font-weight: bold", // vivid red for SKIPPED
  combinator: "color: #3070c0; font-weight: bold", // bold blue for operators
  indent: "color: #a0a0a0", // light gray
  args: "color: #8b8b8b", // medium gray
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
   * End the current group and flush logs to console.
   * Uses console.groupCollapsed for a clean, expandable view.
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

    for (const log of logs) {
      this.#logTreeNode(log);
    }

    // eslint-disable-next-line no-console
    console.groupEnd();
    this.#currentGroup = null;
  }

  /**
   * Log a single node in the condition tree.
   *
   * @param {Object} log - The log entry
   * @param {string} log.type - Condition type
   * @param {Object} [log.args] - Condition arguments
   * @param {boolean} log.result - Pass/fail
   * @param {number} log.depth - Indentation depth
   */
  #logTreeNode({ type, args, result, depth }) {
    const indent = "  ".repeat(depth);
    const icon = result ? ICONS.passed : ICONS.failed;
    const iconStyle = result ? STYLES.passed : STYLES.failed;
    const isCombinator = ["AND", "OR", "NOT"].includes(type);

    if (isCombinator) {
      // eslint-disable-next-line no-console
      console.log(
        `%c${indent}%c${icon}%c %c${type}`,
        STYLES.indent,
        iconStyle,
        "",
        STYLES.combinator,
        args ? `(${args})` : ""
      );
    } else {
      // Condition type has no special formatting
      // eslint-disable-next-line no-console
      console.log(
        `%c${indent}%c${icon}%c ${type}`,
        STYLES.indent,
        iconStyle,
        "",
        args && Object.keys(args).length > 0 ? args : ""
      );
    }
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
   * Check if a group is currently active.
   *
   * @returns {boolean}
   */
  hasActiveGroup() {
    return this.#currentGroup !== null;
  }
}

export const blockDebugLogger = new BlockDebugLogger();
