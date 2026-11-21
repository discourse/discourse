import { waitForPromise } from "@ember/test-waiters";

const PATTERN_TIMEOUT_MS = 1000;
// A busy device can stall a fast pattern once, so only a repeat offender is skipped.
const TIMEOUTS_BEFORE_SKIPPING = 2;

// Regular expression phrases may use syntax only the server supports, so those never match.
const WORKER_SOURCE = `
const regexps = new Map();

onmessage = ({ data: { id, text, sources } }) => {
  sources.forEach((source, index) => {
    if (!regexps.has(source)) {
      try {
        regexps.set(source, new RegExp(source, "iu"));
      } catch {
        regexps.set(source, null);
      }
    }

    postMessage({ id, index, matched: !!regexps.get(source)?.test(text) });
  });
};
`;

function createWorker() {
  const url = URL.createObjectURL(
    new Blob([WORKER_SOURCE], { type: "text/javascript" })
  );

  try {
    return new Worker(url);
  } finally {
    URL.revokeObjectURL(url);
  }
}

// Matches phrase patterns off the main thread, because a pattern that backtracks can run for
// minutes. A pattern that keeps running past the timeout is skipped from then on.
export default class PhraseMatcher {
  #destroyed = false;
  #lastId = 0;
  #queue = Promise.resolve();
  #timeouts = new Map();
  #timeoutMs;
  #worker = null;

  constructor({ timeoutMs = PATTERN_TIMEOUT_MS } = {}) {
    this.#timeoutMs = timeoutMs;
  }

  // Resolves to the set of sources that match the text.
  match(text, sources) {
    // Matches share one worker, so each waits for the one before it.
    const result = this.#queue.then(() =>
      this.#match(
        text,
        sources.filter((source) => !this.#isSkipped(source))
      )
    );
    this.#queue = result.catch(() => {});
    return waitForPromise(result);
  }

  destroy() {
    this.#destroyed = true;
    this.#stopWorker();
  }

  #isSkipped(source) {
    return (this.#timeouts.get(source) ?? 0) >= TIMEOUTS_BEFORE_SKIPPING;
  }

  async #match(text, sources) {
    if (!sources.length || this.#destroyed) {
      return new Set();
    }

    const { matched, slowIndex } = await this.#run(text, sources);
    if (slowIndex === null) {
      return matched;
    }

    const slow = sources[slowIndex];
    this.#timeouts.set(slow, (this.#timeouts.get(slow) ?? 0) + 1);
    this.#stopWorker();

    const rest = await this.#match(text, sources.slice(slowIndex + 1));
    return new Set([...matched, ...rest]);
  }

  #stopWorker() {
    this.#worker?.terminate();
    this.#worker = null;
  }

  // The worker answers for each pattern in order, so the first missing answer is the slow one.
  #run(text, sources) {
    try {
      this.#worker ??= createWorker();
    } catch {
      return Promise.resolve({ matched: new Set(), slowIndex: null });
    }

    const worker = this.#worker;
    const id = ++this.#lastId;
    const matched = new Set();
    let answered = 0;
    let timer;

    return new Promise((resolve) => {
      const finish = (slowIndex) => {
        clearTimeout(timer);
        worker.removeEventListener("message", onMessage);
        worker.removeEventListener("error", onError);
        resolve({ matched, slowIndex });
      };
      const waitForAnswer = () => {
        clearTimeout(timer);
        timer = setTimeout(() => finish(answered), this.#timeoutMs);
      };
      const onMessage = ({ data }) => {
        if (data.id !== id) {
          return;
        }

        if (data.matched) {
          matched.add(sources[data.index]);
        }
        answered = data.index + 1;

        if (answered === sources.length) {
          finish(null);
        } else {
          waitForAnswer();
        }
      };
      // A worker that can't start matches nothing rather than marking every pattern slow.
      const onError = () => {
        this.#stopWorker();
        finish(null);
      };

      worker.addEventListener("message", onMessage);
      worker.addEventListener("error", onError);
      waitForAnswer();
      worker.postMessage({ id, text, sources });
    });
  }
}
