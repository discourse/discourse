import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";

const source = readFileSync(
  new URL("../../public/blog.js", import.meta.url),
  "utf8"
);

function loadDiscussion() {
  const classes = new Set();
  const failure = { hidden: true };
  const frame = { contentWindow: { postMessage() {} }, style: {} };
  let message;
  let script;
  let expired;
  let cleared = false;
  let removed = false;
  const discussion = {
    classList: {
      add: (name) => classes.add(name),
      remove: (name) => classes.delete(name),
    },
    querySelector: () => failure,
  };
  const comments = {
    dataset: {
      discourseUrl: "https://discuss.example.com/",
      topicId: "37",
      title: "Discussion",
    },
    closest: () => discussion,
  };
  const window = {
    addEventListener: (_, handler) => {
      message = handler;
    },
    removeEventListener: () => {
      removed = true;
    },
  };
  vm.runInNewContext(source, {
    window,
    URL,
    setTimeout: (callback) => {
      expired = callback;
      return 1;
    },
    clearTimeout: () => {
      cleared = true;
    },
    getComputedStyle: () => ({ getPropertyValue: () => "" }),
    document: {
      documentElement: {},
      getElementById: (id) => (id === "discourse-comments" ? comments : frame),
      createElement: () => ({}),
      head: {
        appendChild: (element) => {
          script = element;
        },
      },
    },
    IntersectionObserver: class {
      constructor(callback) {
        this.callback = callback;
      }

      observe() {
        this.callback([{ isIntersecting: true }]);
      }

      disconnect() {}
    },
  });
  return {
    embed: window.DiscourseEmbed,
    classes,
    failure,
    frame,
    message: (origin, sender = frame.contentWindow) =>
      message({
        origin,
        source: sender,
        data: { type: "discourse-blog-ready" },
      }),
    expire: () => expired(),
    error: () => script.onerror(),
    loaded: () => script.onload(),
    cleaned: () => cleared && removed,
    ready: () => cleared && !removed,
    resize: (
      height,
      origin = "https://discuss.example.com",
      sender = frame.contentWindow
    ) =>
      message({
        origin,
        source: sender,
        data: { type: "discourse-blog-resize", height },
      }),
  };
}

test("keeps the loading frame hidden until its own trusted readiness message", () => {
  const state = loadDiscussion();
  assert.ok(state.classes.has("is-loading"));
  state.message("https://attacker.example.com");
  assert.ok(state.classes.has("is-loading"));
  state.message("https://discuss.example.com", {});
  assert.ok(state.classes.has("is-loading"));
  state.message("https://discuss.example.com");
  assert.ok(!state.classes.has("is-loading"));
  assert.ok(state.failure.hidden);
  assert.ok(state.ready());
});

for (const event of ["expire", "error"]) {
  test(`${event} replaces the loading frame with the accessible fallback`, () => {
    const state = loadDiscussion();
    state[event]();
    assert.ok(state.classes.has("is-failed"));
    assert.ok(!state.classes.has("is-loading"));
    assert.ok(!state.failure.hidden);
    assert.ok(state.cleaned());
  });
}

test("lets the discussion grow instead of introducing a nested scroll area", () => {
  const { embed } = loadDiscussion();
  assert.equal(embed.dynamicHeight, false);
  assert.equal(embed.embedMinHeight, 280);
  assert.equal(embed.embedMaxHeight, undefined);
});

test("does not force a scrollbar when the frame fits its content", () => {
  const state = loadDiscussion();
  state.loaded();
  assert.equal(state.frame.scrolling, "auto");
});

test("keeps sizing after readiness and rejects unrelated or malformed resize messages", () => {
  const state = loadDiscussion();
  state.message("https://discuss.example.com");
  state.resize(1800.4);
  assert.equal(state.frame.style.height, "1802px");
  state.resize(900);
  assert.equal(state.frame.style.height, "901px");
  for (const height of [null, "800", Infinity, NaN, -1]) {
    state.resize(height);
    assert.equal(state.frame.style.height, "901px");
  }
  state.resize(2000, "https://attacker.example.com");
  state.resize(2000, "https://discuss.example.com", {});
  assert.equal(state.frame.style.height, "901px");
  assert.equal(state.frame.scrolling, "auto");
});
