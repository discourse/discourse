import { render, triggerEvent, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  settleGestureFrame,
  stubPointerCapture,
} from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import RailResizeHandle from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/rail-resize-handle";

const SEL = ".wireframe-rail-resizer";

module("Integration | Wireframe | RailResizeHandle", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    document.body.style.removeProperty("--wf-left-panel");
  });

  test("exposes the WAI-ARIA window-splitter semantics", async function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    rail.setLeftPanelWidth(320);

    await render(<template><RailResizeHandle @side="left" /></template>);

    assert.dom(SEL).hasAttribute("role", "separator");
    assert.dom(SEL).hasAttribute("aria-orientation", "vertical");
    assert.dom(SEL).hasAttribute("tabindex", "0");
    assert.dom(SEL).hasAttribute("aria-label");
    assert.dom(SEL).hasAttribute("aria-valuenow", "320");
    assert.dom(SEL).hasAttribute("aria-valuemin", String(rail.leftPanelMin));
    assert.dom(SEL).hasAttribute("aria-valuemax", String(rail.leftPanelMax));
  });

  test("Arrow keys nudge the width and update aria-valuenow live", async function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    rail.setLeftPanelWidth(320);

    await render(<template><RailResizeHandle @side="left" /></template>);

    await triggerKeyEvent(SEL, "keydown", "ArrowRight");
    assert
      .dom(SEL)
      .hasAttribute("aria-valuenow", "336", "ArrowRight grows the left panel");

    await triggerKeyEvent(SEL, "keydown", "ArrowLeft");
    assert
      .dom(SEL)
      .hasAttribute("aria-valuenow", "320", "ArrowLeft shrinks it back");
  });

  test("Home and End snap to the bounds", async function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    rail.setLeftPanelWidth(320);

    await render(<template><RailResizeHandle @side="left" /></template>);

    await triggerKeyEvent(SEL, "keydown", "End");

    assert
      .dom(SEL)
      .hasAttribute("aria-valuenow", String(rail.leftPanelMax), "End → max");

    await triggerKeyEvent(SEL, "keydown", "Home");

    assert
      .dom(SEL)
      .hasAttribute("aria-valuenow", String(rail.leftPanelMin), "Home → min");
  });

  test("the right rail grows toward the canvas: ArrowLeft widens it", async function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    rail.setRightRailWidth(300);
    await render(<template><RailResizeHandle @side="right" /></template>);

    await triggerKeyEvent(SEL, "keydown", "ArrowLeft");
    assert.dom(SEL).hasAttribute("aria-valuenow", "316");
    await triggerKeyEvent(SEL, "keydown", "ArrowRight");
    assert.dom(SEL).hasAttribute("aria-valuenow", "300");
  });

  test("a pointer drag previews the width live and persists it once released", async function (assert) {
    const rail = this.owner.lookup("service:wireframe-rail");
    const store = this.owner.lookup("service:key-value-store");
    rail.setLeftPanelWidth(320, { commit: true });
    await render(<template><RailResizeHandle @side="left" /></template>);

    const { element: handle } = stubPointerCapture(SEL);
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 320,
      clientY: 100,
    });
    await triggerEvent(handle, "pointermove", {
      pointerId: 1,
      clientX: 360,
      clientY: 100,
    });
    // Moves are reported on the next frame, which settledness does not cover.
    await settleGestureFrame();
    assert.strictEqual(
      rail.leftPanelWidth,
      360,
      "the width follows the pointer"
    );
    assert.strictEqual(
      store.getObject("wireframe_leftPanelWidth"),
      320,
      "but nothing is persisted mid-gesture"
    );

    await triggerEvent(handle, "pointerup", {
      pointerId: 1,
      clientX: 360,
      clientY: 100,
    });
    assert.strictEqual(store.getObject("wireframe_leftPanelWidth"), 360);
    assert.dom(SEL).hasAttribute("aria-valuenow", "360");
  });
});
