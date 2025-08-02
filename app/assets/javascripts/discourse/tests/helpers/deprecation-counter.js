import { registerDeprecationHandler } from "@ember/debug";
import DEPRECATION_WORKFLOW from "discourse/deprecation-workflow";
import { bind } from "discourse/lib/decorators";
import { registerDeprecationHandler as registerDiscourseDeprecationHandler } from "discourse/lib/deprecated";

export default class DeprecationCounter {
  counts = new Map();
  #configById = new Map();

  constructor(config) {
    for (const c of config) {
      this.#configById.set(c.matchId, c.handler);
    }
  }

  start() {
    registerDeprecationHandler(this.handleEmberDeprecation);
    registerDiscourseDeprecationHandler(this.handleDiscourseDeprecation);
  }

  @bind
  handleEmberDeprecation(message, options, next) {
    const { id } = options;
    const matchingConfig = this.#configById.get(id);

    if (matchingConfig !== "silence") {
      this.incrementDeprecation(id);
    }

    next(message, options);
  }

  @bind
  handleDiscourseDeprecation(message, options) {
    let { id } = options;
    id ||= "discourse.(unknown)";

    const matchingConfig = this.#configById.get(id);

    if (matchingConfig !== "silence") {
      this.incrementDeprecation(id);
    }
  }

  incrementDeprecation(id) {
    const existingCount = this.counts.get(id) || 0;
    this.counts.set(id, existingCount + 1);
    if (window.Testem) {
      reportToTestem(id);
    }
  }

  get hasDeprecations() {
    return this.counts.size > 0;
  }

  generateTable() {
    const maxIdLength = Math.max(
      ...Array.from(this.counts.keys()).map((k) => k.length)
    );

    let msg = `| ${"id".padEnd(maxIdLength)} | count |\n`;
    msg += `| ${"".padEnd(maxIdLength, "-")} | ----- |\n`;

    for (const [id, count] of this.counts.entries()) {
      const countString = count.toString();
      msg += `| ${id.padEnd(maxIdLength)} | ${countString.padStart(5)} |\n`;
    }

    return msg;
  }
}

function reportToTestem(id) {
  window.Testem.useCustomAdapter(function (socket) {
    socket.emit("test-metadata", "increment-deprecation", {
      id,
    });
  });
}

export function setupDeprecationCounter(qunit) {
  const deprecationCounter = new DeprecationCounter(DEPRECATION_WORKFLOW);

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
