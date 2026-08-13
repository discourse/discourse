import { find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import Toolbar from "discourse/static/dev-tools/toolbar";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";

/**
 * The toolbar positions itself with `top: min(100dvh - <own height>px, <top>px)`,
 * so the tracked value is read back out of the declaration rather than guessed at.
 *
 * @returns {number} The pixel value the toolbar last wrote for its own top.
 */
function declaredTop() {
  const style = find(".dev-tools-toolbar").getAttribute("style");
  return parseFloat(style.match(/,\s*(-?[\d.]+)px\)/)[1]);
}

module("Integration | Component | DevTools | Toolbar", function (hooks) {
  setupRenderingTest(hooks);

  test("dragging the gripper moves the toolbar by the pointer's travel", async function (assert) {
    await render(<template><Toolbar /></template>);

    const gripper = find(".dev-tools-toolbar .gripper");
    stubPointerCapture(gripper);

    await triggerEvent(gripper, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 10,
      clientY: 300,
      pageX: 10,
      pageY: 300,
    });
    // The first move settles the toolbar against the grab offset captured at the
    // press. Travel is compared from there, because the offset depends on where
    // the toolbar happens to be laid out rather than on the gesture.
    await triggerEvent(gripper, "pointermove", {
      pointerId: 1,
      clientX: 10,
      clientY: 340,
      pageX: 10,
      pageY: 340,
    });
    const settled = declaredTop();

    await triggerEvent(gripper, "pointermove", {
      pointerId: 1,
      clientX: 10,
      clientY: 380,
      pageX: 10,
      pageY: 380,
    });

    assert.strictEqual(
      declaredTop() - settled,
      40,
      "further travel moves the toolbar one pixel per pixel"
    );

    await triggerEvent(gripper, "pointerup", {
      pointerId: 1,
      clientX: 10,
      clientY: 340,
      pageX: 10,
      pageY: 340,
    });
    assert
      .dom(".dev-tools-toolbar")
      .doesNotHaveClass(
        "--dragging",
        "releasing the pointer ends the drag session"
      );
  });

  test("the gripper is marked as dragging only while the pointer is down", async function (assert) {
    await render(<template><Toolbar /></template>);

    const gripper = find(".dev-tools-toolbar .gripper");
    stubPointerCapture(gripper);

    assert
      .dom(".dev-tools-toolbar")
      .doesNotHaveClass("--dragging", "idle to begin with");

    await triggerEvent(gripper, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 10,
      clientY: 300,
      pageX: 10,
      pageY: 300,
    });

    assert
      .dom(".dev-tools-toolbar")
      .hasClass("--dragging", "a press opens a drag session");
    assert
      .dom(document.body)
      .hasClass("dragging", "and marks the page so the cursor holds");

    await triggerEvent(gripper, "pointerup", {
      pointerId: 1,
      clientX: 10,
      clientY: 300,
      pageX: 10,
      pageY: 300,
    });

    assert
      .dom(document.body)
      .doesNotHaveClass("dragging", "the page mark is given back on release");
  });

  test("a cancelled gesture closes the drag session too", async function (assert) {
    await render(<template><Toolbar /></template>);

    const gripper = find(".dev-tools-toolbar .gripper");
    stubPointerCapture(gripper);

    await triggerEvent(gripper, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 10,
      clientY: 300,
      pageX: 10,
      pageY: 300,
    });
    await triggerEvent(gripper, "pointercancel", { pointerId: 1 });

    assert
      .dom(".dev-tools-toolbar")
      .doesNotHaveClass(
        "--dragging",
        "an interrupted gesture does not leave the toolbar stuck dragging"
      );
    assert
      .dom(document.body)
      .doesNotHaveClass(
        "dragging",
        "the cancelled gesture releases the page mark"
      );
  });
});
