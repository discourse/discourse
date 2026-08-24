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

// Detailed per-occurrence records are deduplicated and capped so a noisy
// deprecation in a hot code path can't blow up memory or the reporter payload.
const MAX_DETAIL_ENTRIES = 2000;
// Deep enough to get past the runloop and computed-property machinery which sits
// between a deprecated getter and the code that actually called it.
const MAX_STACK_FRAMES = 60;

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
  details = new Map();
  #origin = null;
  #qunit = null;
  #unflushedDetails = [];

  start(origin, qunit) {
    this.startDiscourseHandler(origin, qunit);
    this.startEmberHandler();
  }

  startDiscourseHandler(origin, qunit) {
    this.#origin = origin;
    this.#qunit = qunit;

    registerDiscourseDeprecationHandler(this.handleDiscourseDeprecation);
  }

  startEmberHandler() {
    registerDeprecationHandler(this.handleEmberDeprecation);
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

    this.recordDetail(id);

    if (window.Testem) {
      reportDeprecationToTestem(id, this.#origin);
    }
    if (isRailsTesting()) {
      // eslint-disable-next-line no-console
      console.count(`deprecation_id:${id}`); // origin will be identified using the spec metadata
    }
  }

  /**
   * Captures the call stack and the surrounding test context for a deprecation,
   * so the CI report can point at both the spec and the deprecated call site.
   * Identical occurrences are collapsed into a single entry with a count.
   */
  recordDetail(id) {
    const stack = captureStack();
    const currentTest = this.#qunit?.config?.current;
    const key = [
      id,
      currentTest?.module?.name,
      currentTest?.testName,
      stack,
    ].join("\u0000");

    const existing = this.details.get(key);
    if (existing) {
      existing.count++;
      return;
    }

    if (this.details.size >= MAX_DETAIL_ENTRIES) {
      return;
    }

    const detail = {
      id,
      origin: this.#origin,
      module: currentTest?.module?.name,
      testName: currentTest?.testName,
      testStack: currentTest?.stack,
      stack,
      count: 1,
    };

    this.details.set(key, detail);
    this.#unflushedDetails.push(detail);

    if (isRailsTesting()) {
      // System specs identify the spec themselves, so only the JS stack is
      // needed here.
      // eslint-disable-next-line no-console
      console.log(`deprecation_detail:${JSON.stringify({ id, stack })}`);
    }
  }

  /**
   * Hands over the details recorded since the last call. Flushing while the run
   * is still in progress keeps the reporter socket alive; a flush deferred to
   * `QUnit.done` races the browser teardown and gets dropped.
   *
   * @returns {Object[]}
   */
  takeDetails() {
    const pending = this.#unflushedDetails;
    this.#unflushedDetails = [];
    return pending;
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

function captureStack() {
  const previousLimit = Error.stackTraceLimit;

  // Browsers default to a handful of frames, which never reaches the caller.
  Error.stackTraceLimit = MAX_STACK_FRAMES;
  const { stack } = new Error();
  Error.stackTraceLimit = previousLimit;

  return stack || "";
}

function reportDeprecationToTestem(id, origin) {
  window.Testem.useCustomAdapter(function (socket) {
    socket.emit("test-metadata", "increment-deprecation", {
      id,
      origin,
    });
  });
}

function reportDeprecationDetailsToTestem(details) {
  window.Testem.useCustomAdapter(function (socket) {
    socket.emit("test-metadata", "deprecation-details", { details });
  });
}

export function setupDeprecationCounter({ QUnit, origin } = {}) {
  const deprecationCounter = new DeprecationCounter();

  // for system specs
  if (isRailsTesting()) {
    deprecationCounter.start(origin, QUnit);
    return;
  }

  if (QUnit) {
    // The counter has to see a deprecation before the handler which raises on
    // it, or anything that raises goes unrecorded and the suites which must stay
    // deprecation-free report nothing at all. Discourse handlers run in
    // registration order and Ember's run in reverse, so the counter registers
    // ahead of `configureRaiseOnDeprecation` for one and behind it for the
    // other.
    deprecationCounter.startDiscourseHandler(origin, QUnit);
    QUnit.begin(() => deprecationCounter.startEmberHandler());

    const flushDetails = () => {
      const pending = deprecationCounter.takeDetails();
      if (window.Testem && pending.length > 0) {
        reportDeprecationDetailsToTestem(pending);
      }
    };

    QUnit.testDone(flushDetails);

    QUnit.done(() => {
      flushDetails();

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
}
