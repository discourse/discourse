import { render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
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
});
