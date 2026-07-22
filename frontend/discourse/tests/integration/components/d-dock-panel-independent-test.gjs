import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import {
  clearRender,
  click,
  find,
  focus,
  render,
  rerender,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import KeyValueStore from "discourse/lib/key-value-store";
import devToolsState from "discourse/static/dev-tools/state";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DDockPanel from "discourse/ui-kit/d-dock-panel";
import dResizeEdge from "discourse/ui-kit/modifiers/d-resize-edge";

const STORE_NAMESPACE = "d_dock_panel_";
const STATE_STORAGE_KEY = "discourse__dev_tools_state";
const REACTIVE_TOOL_ID = "independent-reactive-tool";

class FlagProbe extends Component {
  get value() {
    return devToolsState.getFlag(REACTIVE_TOOL_ID, "enabled");
  }

  <template>
    <span class="flag-probe">{{this.value}}</span>
  </template>
}

function installPointerCaptureSpy(element) {
  const captured = new Set();
  const released = [];

  element.setPointerCapture = (pointerId) => captured.add(pointerId);
  element.hasPointerCapture = (pointerId) => captured.has(pointerId);
  element.releasePointerCapture = (pointerId) => {
    captured.delete(pointerId);
    released.push(pointerId);
  };

  return { captured, released };
}

module("Integration | Component | DDockPanel independent", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.store = new KeyValueStore(STORE_NAMESPACE);
    this.store.abandonLocal();
    this.originalStateStorage =
      window.sessionStorage.getItem(STATE_STORAGE_KEY);
    this.originalReactiveFlag = devToolsState.getFlag(
      REACTIVE_TOOL_ID,
      "enabled"
    );
  });

  hooks.afterEach(function () {
    this.store.abandonLocal();
    devToolsState.setFlag(
      REACTIVE_TOOL_ID,
      "enabled",
      this.originalReactiveFlag
    );

    if (this.originalStateStorage === null) {
      window.sessionStorage.removeItem(STATE_STORAGE_KEY);
    } else {
      window.sessionStorage.setItem(
        STATE_STORAGE_KEY,
        this.originalStateStorage
      );
    }
  });

  test("the open panel remains non-modal while the background is used", async function (assert) {
    this.isOpen = true;
    this.backgroundClicks = 0;
    this.useBackground = () => this.backgroundClicks++;

    await render(
      <template>
        <button
          class="background-button"
          type="button"
          {{on "click" this.useBackground}}
        >
          Use page
        </button>
        <input class="background-input" aria-label="Background input" />
        <DDockPanel @isOpen={{this.isOpen}}>
          <:body>Panel body</:body>
        </DDockPanel>
      </template>
    );

    await click(".background-button");
    await focus(".background-input");

    assert.strictEqual(
      this.backgroundClicks,
      1,
      "background controls remain interactive"
    );
    assert.strictEqual(
      document.activeElement,
      find(".background-input"),
      "focus is not trapped in the panel"
    );
    assert
      .dom(".d-dock-panel")
      .exists("using the page does not dismiss the panel");
    assert.strictEqual(
      getComputedStyle(find(".d-dock-panel-layer")).pointerEvents,
      "none",
      "the viewport layer passes pointer events through"
    );
    assert.strictEqual(
      getComputedStyle(find(".d-dock-panel")).pointerEvents,
      "auto",
      "the panel opts back into pointer interaction"
    );
  });

  test("size is exposed through a custom property and live separator values", async function (assert) {
    await render(
      <template>
        <DDockPanel @isOpen={{true}}>
          <:body>Panel body</:body>
        </DDockPanel>
      </template>
    );

    const panel = find(".d-dock-panel");

    assert.strictEqual(
      panel.style.getPropertyValue("--d-dock-panel-width"),
      "320px",
      "the initial size is published as a CSS custom property"
    );
    assert.strictEqual(
      panel.style.width,
      "",
      "the component does not publish an inline width"
    );
    assert.dom(".d-dock-panel__resizer").hasAttribute("role", "separator");
    assert.dom(".d-dock-panel__resizer").hasAttribute("tabindex", "0");
    assert.dom(".d-dock-panel__resizer").hasAttribute("aria-valuenow", "320");
    assert.dom(".d-dock-panel__resizer").hasAttribute("aria-valuemin", "240");
    assert.dom(".d-dock-panel__resizer").hasAttribute("aria-valuemax", "720");
  });

  test("keyboard resizing steps and clamps, but stores only with a storage key", async function (assert) {
    this.resizeEnds = [];
    this.recordResizeEnd = (width) => this.resizeEnds.push(width);
    const setObject = sinon.spy(KeyValueStore.prototype, "setObject");

    await render(
      <template>
        <DDockPanel @isOpen={{true}} @onResize={{this.recordResizeEnd}}>
          <:body>Panel body</:body>
        </DDockPanel>
      </template>
    );

    await triggerKeyEvent(".d-dock-panel__resizer", "keydown", "ArrowRight");
    assert.dom(".d-dock-panel__resizer").hasAttribute("aria-valuenow", "336");

    await triggerKeyEvent(".d-dock-panel__resizer", "keydown", "End");
    await triggerKeyEvent(".d-dock-panel__resizer", "keydown", "ArrowRight");
    assert.dom(".d-dock-panel__resizer").hasAttribute("aria-valuenow", "720");

    await triggerKeyEvent(".d-dock-panel__resizer", "keydown", "Home");
    await triggerKeyEvent(".d-dock-panel__resizer", "keydown", "ArrowLeft");
    assert.dom(".d-dock-panel__resizer").hasAttribute("aria-valuenow", "240");
    assert.deepEqual(
      this.resizeEnds,
      [336, 720, 720, 240, 240],
      "each supported key commits its clamped value"
    );
    assert.false(
      setObject.called,
      "the persistence boundary is not called without a storage key"
    );
  });

  test("stored width is restored, clamped, and updated after a committed resize", async function (assert) {
    this.store.setObject({ key: "independent-panel", value: 5000 });

    await render(
      <template>
        <DDockPanel @isOpen={{true}} @storageKey="independent-panel">
          <:body>Panel body</:body>
        </DDockPanel>
      </template>
    );

    assert.dom(".d-dock-panel__resizer").hasAttribute("aria-valuenow", "720");

    await triggerKeyEvent(".d-dock-panel__resizer", "keydown", "Home");

    assert.strictEqual(
      this.store.getObject("independent-panel"),
      240,
      "the clamped committed width is persisted"
    );
  });

  test("pointer resizing ignores secondary buttons and mismatched pointer IDs", async function (assert) {
    this.resizeEnds = [];
    this.recordResizeEnd = (width) => this.resizeEnds.push(width);

    await render(
      <template>
        <DDockPanel @isOpen={{true}} @onResize={{this.recordResizeEnd}}>
          <:body>Panel body</:body>
        </DDockPanel>
      </template>
    );

    const resizer = find(".d-dock-panel__resizer");
    const capture = installPointerCaptureSpy(resizer);

    await triggerEvent(resizer, "pointerdown", {
      button: 2,
      clientX: 300,
      pointerId: 1,
    });
    assert.strictEqual(
      capture.captured.size,
      0,
      "a secondary button cannot capture"
    );

    await triggerEvent(resizer, "pointerdown", {
      button: 0,
      clientX: 300,
      pointerId: 7,
    });
    await triggerEvent(resizer, "pointerup", {
      button: 0,
      clientX: 700,
      pointerId: 99,
    });
    assert.deepEqual(
      this.resizeEnds,
      [],
      "a mismatched pointer cannot finish the drag"
    );
    assert.true(capture.captured.has(7), "the active pointer remains captured");

    await triggerEvent(resizer, "pointerup", {
      button: 0,
      clientX: 900,
      pointerId: 7,
    });
    assert.deepEqual(
      this.resizeEnds,
      [720],
      "the matching pointer commits a clamped width"
    );
    assert.deepEqual(
      capture.released,
      [7],
      "the matching pointer capture is released"
    );
  });

  test("a second pointer cannot replace an active drag or strand its capture", async function (assert) {
    this.resizeEnds = [];
    this.recordResizeEnd = (width) => this.resizeEnds.push(width);

    await render(
      <template>
        <DDockPanel @isOpen={{true}} @onResize={{this.recordResizeEnd}}>
          <:body>Panel body</:body>
        </DDockPanel>
      </template>
    );

    const resizer = find(".d-dock-panel__resizer");
    const capture = installPointerCaptureSpy(resizer);

    await triggerEvent(resizer, "pointerdown", {
      button: 0,
      clientX: 300,
      pointerId: 10,
    });
    await triggerEvent(resizer, "pointerdown", {
      button: 0,
      clientX: 400,
      pointerId: 20,
    });
    await triggerEvent(resizer, "pointerup", {
      button: 0,
      clientX: 350,
      pointerId: 10,
    });

    assert.deepEqual(
      this.resizeEnds,
      [370],
      "the pointer that began the drag remains the only pointer allowed to commit it"
    );
    assert.deepEqual(
      capture.released,
      [10],
      "the original pointer capture is not stranded by a second pointer"
    );
    assert.false(capture.captured.has(10), "the original capture is released");
    assert.false(
      capture.captured.has(20),
      "the second pointer is never captured"
    );
  });

  test("destroying during a drag releases capture and removes transient listeners", async function (assert) {
    this.isOpen = true;
    this.resizeEnds = [];
    this.recordResizeEnd = (width) => this.resizeEnds.push(width);

    await render(
      <template>
        <DDockPanel @isOpen={{this.isOpen}} @onResize={{this.recordResizeEnd}}>
          <:body>Panel body</:body>
        </DDockPanel>
      </template>
    );

    const detachedResizer = find(".d-dock-panel__resizer");
    const capture = installPointerCaptureSpy(detachedResizer);

    await triggerEvent(detachedResizer, "pointerdown", {
      button: 0,
      clientX: 300,
      pointerId: 42,
    });

    await clearRender();

    assert.deepEqual(
      capture.released,
      [42],
      "destroy releases the active capture"
    );

    await triggerEvent(detachedResizer, "pointermove", {
      clientX: 500,
      pointerId: 42,
    });
    await triggerEvent(detachedResizer, "pointerup", {
      clientX: 500,
      pointerId: 42,
    });

    assert.deepEqual(
      this.resizeEnds,
      [],
      "detached pointer listeners cannot commit a resize after destroy"
    );
  });

  test("registered tool flags invalidate rendered consumers", async function (assert) {
    devToolsState.setFlag(REACTIVE_TOOL_ID, "enabled", false);

    await render(<template><FlagProbe /></template>);
    assert.dom(".flag-probe").hasText("false", "the initial flag renders");

    devToolsState.setFlag(REACTIVE_TOOL_ID, "enabled", true);
    await rerender();

    assert
      .dom(".flag-probe")
      .hasText("true", "changing the flag rerenders its consumer");
  });

  test("right-docked resize edges invert pointer growth direction", async function (assert) {
    this.previewed = [];
    this.committed = [];
    this.recordPreview = (width) => this.previewed.push(width);
    this.recordCommit = (width) => this.committed.push(width);

    await render(
      <template>
        <div
          class="right-resize-edge"
          {{dResizeEdge
            value=320
            min=240
            max=720
            side="end"
            onResize=this.recordPreview
            onResizeEnd=this.recordCommit
          }}
        ></div>
      </template>
    );

    const edge = find(".right-resize-edge");
    installPointerCaptureSpy(edge);

    await triggerEvent(edge, "pointerdown", {
      button: 0,
      clientX: 500,
      pointerId: 8,
    });
    await triggerEvent(edge, "pointerup", {
      button: 0,
      clientX: 450,
      pointerId: 8,
    });

    assert.deepEqual(
      this.previewed,
      [370],
      "moving left grows a right-docked edge"
    );
    assert.deepEqual(
      this.committed,
      [370],
      "the inverted pointer width is committed"
    );
  });
});
