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
    this.styleEl = document.createElement("style");
    this.styleEl.textContent =
      ".timeline-scrubber { height: 200px; width: 60px; }";
    document.head.appendChild(this.styleEl);
  });

  hooks.afterEach(function () {
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

  test("commits the final cursor position on pointer up", async function (assert) {
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
    await pointerAt(rail, "pointerdown", 0.5);
    await pointerAt(rail, "pointermove", 0.7);
    await pointerAt(rail, "pointerup", 0.7);

    assert.strictEqual(onCommit.callCount, 1);
    assert.strictEqual(onCommit.lastCall.args[0], 0.7);
  });

  test("does not commit when pointerdown lands on an interactive child", async function (assert) {
    const onCommit = sinon.spy();
    const onBack = sinon.spy();
    this.setProperties({ onCommit, onBack });

    await render(
      <template>
        <TimelineScrubber
          @progress={{0.2}}
          @ariaLabel="Topic timeline"
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

  test("keyboard arrows commit a stepped progress", async function (assert) {
    const onCommit = sinon.spy();
    this.setProperties({ onCommit });

    await render(
      <template>
        <TimelineScrubber
          @progress={{0.5}}
          @keyboardStep={{0.1}}
          @onCommit={{this.onCommit}}
        />
      </template>
    );

    await triggerKeyEvent(".timeline-scrubber", "keydown", "ArrowDown");

    assert.strictEqual(onCommit.callCount, 1);
    assert.true(
      Math.abs(onCommit.lastCall.args[0] - 0.6) < 0.0001,
      `expected ~0.6, got ${onCommit.lastCall.args[0]}`
    );
  });
});
