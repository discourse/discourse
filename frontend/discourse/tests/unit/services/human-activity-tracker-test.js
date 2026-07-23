import { triggerEvent } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { processBrowserAttentionChange } from "discourse/lib/user-presence";

const SESSION_ID = "S".repeat(32);

function blur(context) {
  context.focused = false;
  processBrowserAttentionChange();
}

function focus(context) {
  context.focused = true;
  processBrowserAttentionChange();
}

function hide(context) {
  context.visibility = "hidden";
  processBrowserAttentionChange();
}

function pagehide() {
  window.dispatchEvent(new Event("pagehide"));
}

module("Unit | Service | human-activity-tracker", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.clock = { ms: 0 };
    this.focused = true;
    this.visibility = "visible";
    this.sent = [];

    Object.defineProperty(document, "visibilityState", {
      configurable: true,
      get: () => this.visibility,
    });
    sinon.stub(document, "hasFocus").callsFake(() => this.focused);

    this.meta = document.createElement("meta");
    this.meta.name = "discourse-track-view-session-id";
    this.meta.content = SESSION_ID;
    document.head.appendChild(this.meta);

    this.tracker = this.owner.lookup("service:human-activity-tracker");
    this.tracker.now = () => this.clock.ms;
    this.tracker.transport = (body) => this.sent.push(body);
    this.tracker.scheduleFlush = (callback) => {
      this.flushTick = callback;
      return {};
    };
    this.tracker.start();
  });

  hooks.afterEach(function () {
    this.tracker?.stop();
    this.meta.remove();
    delete document.visibilityState;
  });

  test("sends nothing when there was no interaction", function (assert) {
    pagehide();

    assert.strictEqual(this.sent.length, 0);
  });

  test("counts interaction events and reports them on flush", function (assert) {
    window.dispatchEvent(new Event("keydown"));
    window.dispatchEvent(new Event("mousedown"));
    window.dispatchEvent(new Event("scroll"));
    pagehide();

    const payload = this.sent.at(-1);
    assert.strictEqual(payload.session_id, SESSION_ID);
    assert.strictEqual(payload.key_events, 1);
    assert.strictEqual(payload.click_events, 1);
    assert.strictEqual(payload.scroll_events, 1);
  });

  test("counts continuous mouse movement but ignores teleporting jumps", async function (assert) {
    await triggerEvent(document.body, "mousemove", {
      clientX: 10,
      clientY: 10,
    });
    // Within MAX_HUMAN_STEP of the previous point — counted.
    await triggerEvent(document.body, "mousemove", {
      clientX: 30,
      clientY: 30,
    });
    // A large jump — ignored.
    await triggerEvent(document.body, "mousemove", {
      clientX: 900,
      clientY: 900,
    });
    pagehide();

    assert.strictEqual(this.sent.at(-1).mouse_move_events, 1);
  });

  test("reports the time to the first interaction", async function (assert) {
    this.clock.ms = 2500;
    await triggerEvent(document.body, "keydown");

    this.clock.ms = 9000;
    pagehide();

    assert.strictEqual(this.sent.at(-1).time_to_first_interaction_ms, 2500);
  });

  test("accumulates only visible-and-focused time as engaged duration", async function (assert) {
    await triggerEvent(document.body, "keydown");

    this.clock.ms = 4000;
    blur(this);

    this.clock.ms = 10_000;
    focus(this);

    this.clock.ms = 13_000;
    pagehide();

    assert.strictEqual(this.sent.at(-1).engaged_seconds, 7);
  });

  test("flushes the latest snapshot when the tab is hidden", async function (assert) {
    await triggerEvent(document.body, "keydown");

    this.clock.ms = 5000;
    hide(this);

    assert.strictEqual(this.sent.length, 1);
    assert.strictEqual(this.sent.at(-1).engaged_seconds, 5);
  });

  test("caps engaged seconds at the configured maximum", async function (assert) {
    this.tracker.siteSettings.browser_pageview_max_engaged_seconds = 5;
    await triggerEvent(document.body, "keydown");

    this.clock.ms = 9000;
    pagehide();

    assert.strictEqual(this.sent.at(-1).engaged_seconds, 5);
  });

  test("throttles sends to at most one every three seconds", async function (assert) {
    await triggerEvent(document.body, "keydown");

    this.clock.ms = 1000;
    blur(this);

    this.clock.ms = 2000;
    focus(this);
    this.clock.ms = 3000;
    blur(this);

    assert.strictEqual(this.sent.length, 1);

    this.clock.ms = 6000;
    focus(this);
    this.clock.ms = 7000;
    blur(this);

    assert.strictEqual(this.sent.length, 2);
  });

  test("always flushes on pagehide, bypassing the throttle", async function (assert) {
    await triggerEvent(document.body, "keydown");

    this.clock.ms = 1000;
    blur(this);

    this.clock.ms = 2000;
    focus(this);
    this.clock.ms = 3000;
    pagehide();

    assert.strictEqual(this.sent.length, 2);
  });

  test("keeps sending periodic snapshots on each flush cadence", async function (assert) {
    await triggerEvent(document.body, "keydown");

    this.clock.ms = 180_000;
    this.flushTick();

    this.clock.ms = 360_000;
    this.flushTick();

    assert.strictEqual(this.sent.length, 2);
  });
});
