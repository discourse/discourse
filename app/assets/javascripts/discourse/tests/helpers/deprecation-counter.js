import { registerDeprecationHandler } from "@ember/debug";
import DeprecationWorkflow from "discourse/deprecation-workflow";
import { bind } from "discourse/lib/decorators";
import {
  isDeprecationSilenced,
  registerDeprecationHandler as registerDiscourseDeprecationHandler,
} from "discourse/lib/deprecated";

export default class DeprecationCounter {
  counts = new Map();

  start() {
    registerDeprecationHandler(this.handleEmberDeprecation);
    registerDiscourseDeprecationHandler(this.handleDiscourseDeprecation);
  }

  shouldCount(id) {
    const handlers = DeprecationWorkflow.find(id)?.handler?.split("|");

    const isSilenced = isDeprecationSilenced(id);
    const hasSilence = handlers?.includes("silence") ?? false;
    const hasCounter = handlers?.includes("counter") ?? false;

    // Increment when the id is not silenced and either:
    // - no handlers are configured
    // - the handler "silence" is not included
    // - explicitly includes the handler "counter"
    return !isSilenced && (!handlers || !hasSilence || hasCounter);
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

    for (const [id, count] of this.counts.entries()) {
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
