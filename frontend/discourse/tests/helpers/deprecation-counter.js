import { registerDeprecationHandler } from "@ember/debug";
import DeprecationWorkflow from "discourse/deprecation-workflow";
import { bind } from "discourse/lib/decorators";
import {
  isDeprecationSilenced,
  registerDeprecationHandler as registerDiscourseDeprecationHandler,
} from "discourse/lib/deprecated";
import { isRailsTesting, isTesting } from "discourse/lib/environment";

/**
 * Set of deprecation IDs that should be skipped when counting deprecations.
 * @type {Set<string>}
 */
const skipCountIds = new Set();

/**
 * Marks a deprecation ID to be skipped when counting deprecations during tests.
 * This is useful when you want to temporarily ignore specific deprecations
 * without affecting the deprecation counter.
 *
 * USE ONLY FOR TESTING PURPOSES
 *
 * @param {string} id - The deprecation ID to skip counting
 * @throws {Error} If called outside of a QUnit test environment
 * @example
 * skipCountingDeprecation('my-deprecation-id');
 */
export function skipCountingDeprecation(id) {
  if (!isTesting()) {
    throw new Error("skipCountingDeprecation can only be used in QUnit tests.");
  }

  skipCountIds.add(id);
}

/**
 * Restores counting for a previously skipped deprecation ID.
 * Use this to re-enable deprecation counting for a specific ID that was
 * previously excluded via skipCountingDeprecation.
 *
 * USE ONLY FOR TESTING PURPOSES
 *
 * @param {string} id - The deprecation ID to restore counting for
 * @throws {Error} If called outside of a QUnit test environment
 * @example
 * restoreCountingDeprecation('my-deprecation-id');
 */
export function restoreCountingDeprecation(id) {
  if (!isTesting()) {
    throw new Error("resetSkipDeprecations can only be used in QUnit tests.");
  }

  skipCountIds.delete(id);
}

export default class DeprecationCounter {
  counts = new Map();

  start() {
    registerDeprecationHandler(this.handleEmberDeprecation);
    registerDiscourseDeprecationHandler(this.handleDiscourseDeprecation);
  }

  shouldCount(id) {
    return (
      !skipCountIds.has(id) &&
      !isDeprecationSilenced(id) &&
      DeprecationWorkflow.shouldCount(id)
    );
  }

  @bind
  handleEmberDeprecation(message, options, next) {
    const { id } = options;

    if (this.shouldCount(id)) {
      this.incrementCount(id);
    }

    next(message, options);
  }

  @bind
  handleDiscourseDeprecation(message, options) {
    const id = options?.id || "discourse.(unknown)";

    if (this.shouldCount(id)) {
      this.incrementCount(id);
    }
  }

  incrementCount(id) {
    const existingCount = this.counts.get(id) || 0;
    this.counts.set(id, existingCount + 1);
    if (window.Testem) {
      reportDeprecationToTestem(id);
    }
    if (isRailsTesting()) {
      // eslint-disable-next-line no-console
      console.count(`deprecation_id:${id}`); // source will be identified using the spec metadata
    }
  }

  get hasDeprecations() {
    return this.counts.size > 0;
  }

  generateTable() {
    const idColumn = "id";
    const countColumn = "count";

    const maxIdLength = Math.max(
      ...Array.from(this.counts.keys())
        .concat(idColumn)
        .map((k) => k.length)
    );

    let msg = `| ${idColumn.padEnd(maxIdLength)} |    ${countColumn} |\n`;
    msg += `| ${"".padEnd(maxIdLength, "-")} | -------- |\n`;

    for (const [id, count] of Array.from(this.counts.entries()).sort(
      ([id1], [id2]) => {
        // sort id alphabetically
        return id1.localeCompare(id2);
      }
    )) {
      const countString = count.toString();
      msg += `| ${id.padEnd(maxIdLength)} | ${countString.padStart(8)} |\n`;
    }

    return msg;
  }
}

function reportDeprecationToTestem(id) {
  window.Testem.useCustomAdapter(function (socket) {
    socket.emit("test-metadata", "increment-deprecation", {
      id,
    });
  });
}

export function setupDeprecationCounter(qunit) {
  const deprecationCounter = new DeprecationCounter();

  qunit.begin(() => deprecationCounter.start());

  qunit.done(() => {
    if (window.Testem) {
      return;
    } else if (deprecationCounter.hasDeprecations) {
      // eslint-disable-next-line no-console
      console.warn(
        `[Discourse Deprecation Counter] Test run completed with deprecations:\n\n${deprecationCounter.generateTable()}`
      );
    } else {
      // eslint-disable-next-line no-console
      console.log("[Discourse Deprecation Counter] No deprecations found");
    }
  });
}
