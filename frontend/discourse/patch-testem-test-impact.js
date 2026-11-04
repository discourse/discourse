const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const BrowserTestRunner = require("testem/lib/runners/browser_test_runner");

const REPO_ROOT = path.resolve(__dirname, "..", "..");
const OUTPUT_DIR = path.join(REPO_ROOT, "tmp", "test_impact");
const BINDING = "__testImpactTake";

// Records the JavaScript each top-level QUnit module runs, for the test impact
// map (TEST_IMPACT_RECORD=1; see script/test_impact). Takes Chrome's function
// coverage over the DevTools port of each browser testem launches, whenever
// the page (tests/helpers/test-impact.js) reaches a new top-level module and
// waits. Writes recordings in the format of script/test_impact/recorder.rb,
// with the location of the module's first test in place of a spec file, which
// script/test_impact/resolve_js maps to the test file.
class Recording {
  #runner;
  #socket;
  #session;
  #pending = new Map();
  #nextId = 1;
  #origin;
  #functions = new Map();
  #segment = null;
  #entries = [];
  #queue = Promise.resolve();
  #failed = false;
  // Why modules might go unrecorded, summarized at the end.
  #navigations = 0;
  #pagesCreated = 0;
  #detached = null;

  constructor(runner) {
    this.#runner = runner;
    this.ready = this.#connect().catch((error) => this.#fail(error));
  }

  async finish() {
    await this.ready;
    await this.#queue;
    try {
      if (!this.#failed) {
        await this.#take();
        await this.#write();
      }
    } catch (error) {
      this.#fail(error);
    }
    await this.#summarize();
    this.#socket?.close();
  }

  async #summarize() {
    let page = null;
    try {
      const { result } = await this.#send("Runtime.evaluate", {
        expression: "JSON.stringify(window.__testImpactStats ?? null)",
        returnByValue: true,
      });
      page = JSON.parse(result.value);
    } catch {
      // The page went away.
    }
    // eslint-disable-next-line no-console
    console.error(
      `[test-impact] browser ${this.#runner.launcherId}: ${JSON.stringify({
        recorded: this.#entries.length,
        page,
        attaches: this.#runner.testImpactAttaches,
        navigations: this.#navigations,
        pagesCreated: this.#pagesCreated,
        detached: this.#detached,
        failed: this.#failed,
      })}`
    );
  }

  async #connect() {
    const url = this.#runner.process?.stderr.match(
      /DevTools listening on (ws:\/\/\S+)/
    )?.[1];
    if (!url) {
      throw new Error("no DevTools URL in the browser's output");
    }

    this.#socket = new WebSocket(url);
    this.#socket.addEventListener("message", (event) =>
      this.#receive(JSON.parse(event.data))
    );
    await new Promise((resolve, reject) => {
      this.#socket.addEventListener("open", resolve);
      this.#socket.addEventListener("error", () =>
        reject(new Error(`no connection to ${url}`))
      );
    });

    const { targetInfos } = await this.#send("Target.getTargets");
    const page = targetInfos.find((target) => target.type === "page");
    if (!page) {
      throw new Error("no page in the browser");
    }
    this.#origin = new URL(page.url).origin;
    ({ sessionId: this.#session } = await this.#send("Target.attachToTarget", {
      targetId: page.targetId,
      flatten: true,
    }));

    await this.#send("Profiler.enable");
    // Whether each function ran is all the map needs.
    await this.#send("Profiler.startPreciseCoverage", {
      callCount: false,
      detailed: false,
    });
    await this.#send("Runtime.addBinding", { name: BINDING });
    await this.#send("Page.enable");
    await this.#send("Target.setDiscoverTargets", { discover: true });
  }

  #send(method, params = {}) {
    const id = this.#nextId++;
    const message = { id, method, params };
    if (this.#session && !method.startsWith("Target.")) {
      message.sessionId = this.#session;
    }
    this.#socket.send(JSON.stringify(message));
    return new Promise((resolve, reject) =>
      this.#pending.set(id, { resolve, reject })
    );
  }

  #receive(message) {
    const waiting = this.#pending.get(message.id);
    if (waiting) {
      this.#pending.delete(message.id);
      message.error
        ? waiting.reject(new Error(message.error.message))
        : waiting.resolve(message.result);
    } else if (
      message.method === "Runtime.bindingCalled" &&
      message.params.name === BINDING
    ) {
      this.#queue = this.#queue.then(() =>
        this.#nextModule(JSON.parse(message.params.payload))
      );
    } else if (
      message.method === "Page.frameNavigated" &&
      !message.params.frame.parentId
    ) {
      this.#navigations++;
    } else if (
      message.method === "Target.targetCreated" &&
      message.params.targetInfo.type === "page"
    ) {
      this.#pagesCreated++;
    } else if (
      message.method === "Target.detachedFromTarget" &&
      message.params.sessionId === this.#session
    ) {
      this.#detached = "detached";
    } else if (message.method === "Target.targetCrashed") {
      this.#detached = `crashed: ${message.params.status}`;
    }
  }

  // Ends the module that ran, starts the next one, and lets the page go on
  // even when taking coverage failed.
  async #nextModule({ module, stack }) {
    try {
      if (!this.#failed) {
        await this.#take();
        this.#segment = {
          module,
          location: firstFrame(stack),
          started: performance.now(),
        };
      }
    } catch (error) {
      this.#fail(error);
    }

    try {
      await this.#send("Runtime.evaluate", {
        expression: "window.__testImpactTaken?.()",
      });
    } catch {
      // The page went away.
    }
  }

  async #take() {
    const { result } = await this.#send("Profiler.takePreciseCoverage");
    const ran = {};

    for (const entry of result) {
      const url = new URL(entry.url, "file:///");
      if (url.origin !== this.#origin || !url.pathname.endsWith(".js")) {
        continue;
      }
      const known = this.#functions.get(entry.url) || new Map();
      this.#functions.set(entry.url, known);

      for (const { ranges } of entry.functions) {
        const [whole] = ranges;
        const key = `${whole.startOffset},${whole.endOffset}`;
        let offsets = known.get(key);
        if (!offsets) {
          offsets = [whole.startOffset, whole.endOffset];
          known.set(key, offsets);
        }
        if (whole.count > 0) {
          (ran[entry.url] ||= []).push(offsets);
        }
      }
    }

    // What ran before the first module is the test page booting.
    if (this.#segment?.location) {
      this.#entries.push({
        spec_location: this.#segment.location,
        module: this.#segment.module,
        seconds: (performance.now() - this.#segment.started) / 1000,
        js: ran,
      });
    }
  }

  // Offsets of each line's start, in UTF-16 code units as V8 counts them.
  async #starts(url) {
    const source = await (await fetch(url)).text();
    const starts = [0];
    for (let index = 0; index < source.length; index++) {
      if (source.charCodeAt(index) === 10) {
        starts.push(index + 1);
      }
    }
    return starts;
  }

  // Offsets become line/column ranges only now: fetching every script while
  // the tests wait would stall them.
  async #write() {
    const ranges = new Map();
    const functions = {};
    for (const [url, known] of this.#functions) {
      const starts = await this.#starts(url);
      const script = path.basename(new URL(url).pathname);
      const byOffsets = new Map();
      for (const offsets of known.values()) {
        byOffsets.set(offsets, [
          ...position(starts, offsets[0]),
          ...position(starts, offsets[1] - 1),
        ]);
      }
      ranges.set(url, { script, byOffsets });
      functions[script] = [...byOffsets.values()];
    }

    const entries = this.#entries.map((entry) => {
      const js = {};
      for (const [url, ran] of Object.entries(entry.js)) {
        const { script, byOffsets } = ranges.get(url);
        js[script] = ran.map((offsets) => byOffsets.get(offsets));
      }
      return { ...entry, js };
    });
    const lines = [...entries, { js_functions: functions }].map((line) =>
      JSON.stringify(line)
    );

    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    const name = `recording-qunit-${process.pid}-${crypto.randomUUID()}.jsonl.gz`;
    fs.writeFileSync(
      path.join(OUTPUT_DIR, name),
      zlib.gzipSync(lines.join("\n") + "\n")
    );
  }

  // Stops recording, but the page still waits on each module.
  #fail(error) {
    if (!this.#failed) {
      // eslint-disable-next-line no-console
      console.error(`[test-impact] not recording: ${error.message}`);
    }
    this.#failed = true;
  }
}

function position(starts, offset) {
  let low = 0;
  let high = starts.length - 1;
  while (low < high) {
    const middle = Math.ceil((low + high) / 2);
    if (starts[middle] <= offset) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  return [low + 1, offset - starts[low] + 1];
}

// [script, line, column] of the first frame of a stack trace.
function firstFrame(stack) {
  const match = stack?.match(/(https?:\/\/[^\s()]+):(\d+):(\d+)/);
  if (match) {
    return [
      path.basename(new URL(match[1]).pathname),
      Number(match[2]),
      Number(match[3]),
    ];
  }
}

function patchTestemTestImpact() {
  if (process.env.TEST_IMPACT_RECORD !== "1") {
    return;
  }

  const originalTryAttach = BrowserTestRunner.prototype.tryAttach;
  BrowserTestRunner.prototype.tryAttach = function (browser, id, socket) {
    const result = originalTryAttach.call(this, browser, id, socket);
    if (result !== false) {
      this.testImpactAttaches = (this.testImpactAttaches || 0) + 1;
    }
    if (result !== false && !this.testImpact) {
      this.testImpact = new Recording(this);
    }
    return result;
  };

  // Before the browser is closed, so the last module's coverage is taken.
  const originalExit = BrowserTestRunner.prototype.exit;
  BrowserTestRunner.prototype.exit = function (...args) {
    const recording = this.testImpact;
    this.testImpact = null;
    return (recording?.finish() || Promise.resolve()).then(() =>
      originalExit.apply(this, args)
    );
  };
}

module.exports = patchTestemTestImpact;
