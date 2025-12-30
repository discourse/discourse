/**
 * Block debug logger with styled console output.
 *
 * Provides grouped, hierarchical logging for condition evaluations.
 * Logs are grouped by block, showing condition trees with pass/fail status.
 *
 * @module discourse/lib/blocks/debug-logger
 */

const STYLES = {
  blockName: "color: #9c27b0; font-weight: bold",
  outletName: "color: #2196f3",
  passed: "color: #4caf50; font-weight: bold",
  failed: "color: #f44336; font-weight: bold",
  conditionType: "color: #ff9800",
  combinator: "color: #607d8b; font-weight: bold",
  indent: "color: #9e9e9e",
  args: "color: #607d8b",
};

const ICONS = {
  passed: "\u2713",
  failed: "\u2717",
  block: "\u25A0",
};

/**
 * Block debug logger class.
 * Provides grouped console output for block condition evaluations.
 */
class BlockDebugLogger {
  /**
   * Current evaluation group context.
   *
   * @type {{blockName: string, outletName: string, logs: Array}|null}
   */
  #currentGroup = null;

  /**
   * Start a new evaluation group for a block render.
   * All subsequent logCondition calls will be collected in this group
   * until endGroup is called.
   *
   * @param {string} blockName - The block being evaluated
   * @param {string} outletName - The outlet context
   */
  startGroup(blockName, outletName) {
    this.#currentGroup = { blockName, outletName, logs: [] };
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
   * End the current group and flush logs to console.
   * Uses console.groupCollapsed for a clean, expandable view.
   *
   * @param {boolean} finalResult - Whether the block will render
   */
  endGroup(finalResult) {
    if (!this.#currentGroup) {
      return;
    }

    const { blockName, outletName, logs } = this.#currentGroup;

    if (logs.length === 0) {
      this.#currentGroup = null;
      return;
    }

    const status = finalResult ? "RENDERED" : "SKIPPED";
    const statusStyle = finalResult ? STYLES.passed : STYLES.failed;
    const icon = finalResult ? ICONS.passed : ICONS.failed;

    // eslint-disable-next-line no-console
    console.groupCollapsed(
      `%c[Blocks]%c ${ICONS.block} %c${blockName}%c ${icon} %c${status}%c in %c${outletName}`,
      STYLES.conditionType,
      "",
      STYLES.blockName,
      "",
      statusStyle,
      "",
      STYLES.outletName
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
      // eslint-disable-next-line no-console
      console.log(
        `%c${indent}%c${icon}%c %c${type}%c`,
        STYLES.indent,
        iconStyle,
        "",
        STYLES.conditionType,
        STYLES.args,
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
