import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import {
  click,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import TimelineScrubber from "discourse/components/timeline-scrubber";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// Helper: emit a pointer event with a clientY that maps to the desired
// progress within the rail's travel range. The primitive maps the cursor to
// the scroller center, while CSS positions the scroller top.
async function pointerAt(rail, type, progress) {
  const rect = rail.getBoundingClientRect();
  const scroller = rail.querySelector(".timeline-scroller");
  const scrollerHeight = scroller.getBoundingClientRect().height || 50;
  const travel = Math.max(1, rect.height - scrollerHeight);
  const clientY = rect.top + scrollerHeight / 2 + travel * progress;
  await triggerEvent(rail, type, {
    clientY,
    pointerId: 1,
    button: 0,
    buttons: type === "pointerup" ? 0 : 1,
  });
}

function railProgress(rail) {
  // The primitive writes `--scrubber-progress: 0.XXXX` as inline style.
  // We parse that rather than rely on computed style because jsdom-style
  // test environments may not actually apply the CSS custom property.
  const match = rail
    .getAttribute("style")
    ?.match(/--scrubber-progress:\s*([0-9.]+)/);
  return match ? parseFloat(match[1]) : null;
}

class Wrapper {
  @tracked progress = 0.2;
}

module("Integration | Component | timeline-scrubber", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.clock = sinon.useFakeTimers({ shouldClearNativeTimers: true });

    // The primitive has no intrinsic height — consumers set it. Without
    // a measurable rail the cursor→progress math returns 0 in the test
    // environment. Inject a stylesheet rather than a style attribute
    // (the primitive's style={{...}} would clobber inline style).
    this.styleEl = document.createElement("style");
    this.styleEl.textContent =
      ".timeline-scrubber { height: 200px; width: 60px; }";
    document.head.appendChild(this.styleEl);
  });

  hooks.afterEach(function () {
    this.clock.restore();
    this.styleEl.remove();
  });

  test("handle follows @progress when not interacting", async function (assert) {
    const state = new Wrapper();
    this.setProperties({ state });

    await render(
      <template><TimelineScrubber @progress={{state.progress}} /></template>
    );

    const rail = document.querySelector(".timeline-scrubber");
    assert.strictEqual(railProgress(rail), 0.2, "starts at @progress");

    state.progress = 0.7;
    await settled();
    assert.strictEqual(railProgress(rail), 0.7, "follows @progress updates");
  });

  test("handle follows the cursor while dragging", async function (assert) {
    const state = new Wrapper();
    this.setProperties({ state });

    await render(
      <template><TimelineScrubber @progress={{state.progress}} /></template>
    );

    const rail = document.querySelector(".timeline-scrubber");
    await pointerAt(rail, "pointerdown", 0.5);
    assert.strictEqual(
      railProgress(rail),
      0.5,
      "snaps to cursor on pointerdown"
    );

    await pointerAt(rail, "pointermove", 0.8);
    assert.strictEqual(
      railProgress(rail),
      0.8,
      "follows cursor on pointermove"
    );
  });

  test("handle stays at the committed position until @progress catches up", async function (assert) {
    const state = new Wrapper();
    const onCommit = sinon.spy();
    this.setProperties({ state, onCommit });

    await render(
      <template>
        <TimelineScrubber
          @progress={{state.progress}}
          @onCommit={{this.onCommit}}
        />
      </template>
    );

    const rail = document.querySelector(".timeline-scrubber");

    // User clicks at 0.5 — the parent's @progress is still 0.2.
    await pointerAt(rail, "pointerdown", 0.5);
    await pointerAt(rail, "pointerup", 0.5);

    assert.strictEqual(onCommit.callCount, 1, "onCommit fires once");
    assert.strictEqual(
      railProgress(rail),
      0.5,
      "handle pinned to committed value (NOT snapped back to stale @progress)"
    );

    // Parent finally updates @progress — handle should follow.
    state.progress = 0.5;
    await settled();
    assert.strictEqual(
      railProgress(rail),
      0.5,
      "handle stays at 0.5 once @progress matches (no second jump)"
    );
  });

  test("handle releases the latch once @progress lands within tolerance", async function (assert) {
    const state = new Wrapper();
    this.setProperties({ state });

    await render(
      <template><TimelineScrubber @progress={{state.progress}} /></template>
    );

    const rail = document.querySelector(".timeline-scrubber");

    await pointerAt(rail, "pointerdown", 0.5);
    await pointerAt(rail, "pointerup", 0.5);
    assert.strictEqual(railProgress(rail), 0.5, "latched at clicked value");

    // @progress lands close to clicked value (within 5% tolerance) —
    // e.g., page-aligned commit landing at 0.48 instead of exactly 0.5.
    state.progress = 0.48;
    await settled();
    assert.strictEqual(
      railProgress(rail),
      0.48,
      "handle follows @progress once it's within tolerance of the latch"
    );
  });

  test("intermediate @progress changes during navigation do not break the latch", async function (assert) {
    const state = new Wrapper();
    this.setProperties({ state });

    await render(
      <template><TimelineScrubber @progress={{state.progress}} /></template>
    );

    const rail = document.querySelector(".timeline-scrubber");

    await pointerAt(rail, "pointerdown", 0.7);
    await pointerAt(rail, "pointerup", 0.7);
    assert.strictEqual(railProgress(rail), 0.7, "latched");

    // @progress wobbles to an intermediate value during navigation
    // (e.g., #updateActive picks up a transient DOM state). Far from
    // the latched value, so the latch must hold.
    state.progress = 0.3;
    await settled();
    assert.strictEqual(
      railProgress(rail),
      0.7,
      "intermediate wobble doesn't unlatch — handle stays where the user dropped it"
    );

    // Final @progress arrives near the latched value, releases.
    state.progress = 0.69;
    await settled();
    assert.strictEqual(railProgress(rail), 0.69, "final value releases");
  });

  test("safety-net timeout releases the latch even if @progress never catches up", async function (assert) {
    const state = new Wrapper();
    this.setProperties({ state });

    await render(
      <template><TimelineScrubber @progress={{state.progress}} /></template>
    );

    const rail = document.querySelector(".timeline-scrubber");

    await pointerAt(rail, "pointerdown", 0.9);
    await pointerAt(rail, "pointerup", 0.9);
    assert.strictEqual(railProgress(rail), 0.9, "latched");

    // @progress never updates. After 2s the safety-net should clear.
    this.clock.tick(2100);
    await settled();
    assert.strictEqual(
      railProgress(rail),
      0.2,
      "latch auto-releases after timeout so a wrong-spot commit isn't permanent"
    );
  });

  test("once latch releases via tolerance, later @progress changes are not re-latched", async function (assert) {
    const state = new Wrapper();
    this.setProperties({ state });

    await render(
      <template><TimelineScrubber @progress={{state.progress}} /></template>
    );

    const rail = document.querySelector(".timeline-scrubber");

    await pointerAt(rail, "pointerdown", 0.5);
    await pointerAt(rail, "pointerup", 0.5);

    // @progress catches up within tolerance — latch should release.
    state.progress = 0.48;
    await settled();
    assert.strictEqual(railProgress(rail), 0.48, "latch released");

    // User scrolls; @progress drifts well outside the original
    // tolerance. The handle must follow — NOT re-engage the latch.
    state.progress = 0.2;
    await settled();
    assert.strictEqual(
      railProgress(rail),
      0.2,
      "released latch stays released — handle follows @progress"
    );
  });

  test("slots receive dragging state so consumers can react to active drag", async function (assert) {
    const state = new Wrapper();
    this.setProperties({ state });

    await render(
      <template>
        <TimelineScrubber @progress={{state.progress}}>
          <:handle as |progress dragging|>
            <span class="state">{{if dragging "dragging" "idle"}}</span>
          </:handle>
        </TimelineScrubber>
      </template>
    );

    const rail = document.querySelector(".timeline-scrubber");
    const stateEl = document.querySelector(".state");

    assert.strictEqual(stateEl.textContent, "idle", "idle initially");

    await pointerAt(rail, "pointerdown", 0.5);
    assert.strictEqual(
      stateEl.textContent,
      "dragging",
      "yields dragging=true while pointer is down"
    );

    await pointerAt(rail, "pointerup", 0.5);
    assert.strictEqual(
      stateEl.textContent,
      "idle",
      "yields dragging=false after release"
    );
  });

  test("slots receive the latch-aware progress so labels stay in sync with the handle", async function (assert) {
    const state = new Wrapper();
    this.setProperties({ state });

    await render(
      <template>
        <TimelineScrubber @progress={{state.progress}}>
          <:handle as |progress|>
            <span class="readout">{{progress}}</span>
          </:handle>
        </TimelineScrubber>
      </template>
    );

    const rail = document.querySelector(".timeline-scrubber");
    const readout = document.querySelector(".readout");

    assert.strictEqual(readout.textContent, "0.2", "yields @progress idle");

    await pointerAt(rail, "pointerdown", 0.5);
    assert.strictEqual(
      readout.textContent,
      "0.5",
      "yields drag position while dragging"
    );

    await pointerAt(rail, "pointerup", 0.5);
    assert.strictEqual(
      readout.textContent,
      "0.5",
      "yields latched value after release — readout does NOT flicker back to stale @progress"
    );

    state.progress = 0.5;
    await settled();
    assert.strictEqual(
      readout.textContent,
      "0.5",
      "yields @progress once it matches"
    );
  });

  test("starting a new drag clears any prior latch", async function (assert) {
    const state = new Wrapper();
    this.setProperties({ state });

    await render(
      <template><TimelineScrubber @progress={{state.progress}} /></template>
    );

    const rail = document.querySelector(".timeline-scrubber");

    // First commit — latches at 0.6.
    await pointerAt(rail, "pointerdown", 0.6);
    await pointerAt(rail, "pointerup", 0.6);
    assert.strictEqual(railProgress(rail), 0.6);

    // Second drag starts before @progress catches up.
    await pointerAt(rail, "pointerdown", 0.3);
    assert.strictEqual(
      railProgress(rail),
      0.3,
      "new drag overrides the prior latch"
    );
  });

  test("keyboard interaction commits bounded progress", async function (assert) {
    const state = new Wrapper();
    const onCommit = sinon.spy((progress) => (state.progress = progress));
    this.setProperties({ state, onCommit });

    await render(
      <template>
        <TimelineScrubber
          @progress={{state.progress}}
          @ariaLabel="Topic timeline"
          @keyboardStep={{0.1}}
          @onCommit={{this.onCommit}}
        />
      </template>
    );

    const rail = document.querySelector(".timeline-scrubber");
    await triggerKeyEvent(rail, "keydown", "ArrowDown");

    assert.strictEqual(
      Number(onCommit.lastCall.args[0].toFixed(4)),
      0.3,
      "increments by step"
    );

    await triggerKeyEvent(rail, "keydown", "Home");
    assert.strictEqual(onCommit.lastCall.args[0], 0, "jumps to the start");

    await triggerKeyEvent(rail, "keydown", "End");
    assert.strictEqual(onCommit.lastCall.args[0], 1, "jumps to the end");
  });

  test("interactive track controls do not start scrubbing", async function (assert) {
    const state = new Wrapper();
    const onCommit = sinon.spy();
    const onBack = sinon.spy();
    this.setProperties({ state, onCommit, onBack });

    await render(
      <template>
        <TimelineScrubber
          @progress={{state.progress}}
          @ariaLabel="Topic timeline"
          @interactiveTrack={{true}}
          @onCommit={{this.onCommit}}
        >
          <:track>
            <button
              type="button"
              class="track-button"
              {{on "click" this.onBack}}
            >
              Back
            </button>
          </:track>
        </TimelineScrubber>
      </template>
    );

    await click(".track-button");

    assert.true(onBack.calledOnce, "runs the track control action");
    assert.true(onCommit.notCalled, "does not commit a scrub");
  });
});
