import { click, find, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  settleGestureFrame,
  stubPointerCapture,
} from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";

let nextPointerId = 1;

async function startDrawerDrag(targetSelector) {
  const target = find(targetSelector);
  const gestureSurface = target.closest(".menu-panel.slide-in, .header-cloak");
  const pointerId = nextPointerId++;

  stubPointerCapture(gestureSurface);

  const drag = {
    gestureSurface,
    pointerId,
    x: 200,
    y: 200,
  };

  await triggerEvent(target, "pointerdown", {
    button: 0,
    pointerId,
    clientX: drag.x,
    clientY: drag.y,
  });

  return drag;
}

async function moveDrawerDrag(drag, { x = drag.x, y = drag.y }) {
  drag.x = x;
  drag.y = y;

  await triggerEvent(drag.gestureSurface, "pointermove", {
    pointerId: drag.pointerId,
    clientX: drag.x,
    clientY: drag.y,
  });
}

async function endDrawerDrag(drag) {
  await triggerEvent(drag.gestureSurface, "pointerup", {
    pointerId: drag.pointerId,
    clientX: drag.x,
    clientY: drag.y,
  });
}

acceptance("Mobile - menu drawer gestures", function (needs) {
  needs.mobileView();
  needs.user();

  test("dragging the hamburger drawer closed", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    assert.dom(document.documentElement).hasClass(/scroll-lock/);

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { x: drag.x - 100 });
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist("it closes the hamburger drawer on a left drag");
    assert.dom(document.documentElement).doesNotHaveClass(/scroll-lock/);
  });

  test("dragging from the cloak closes the hamburger drawer", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const drag = await startDrawerDrag(".header-cloak");
    await moveDrawerDrag(drag, { x: drag.x - 100 });
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist("the cloak drag closes instead of reopening the drawer");
    assert.dom(document.documentElement).doesNotHaveClass(/scroll-lock/);
  });

  test("a short drag settles the hamburger drawer open", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { x: drag.x - 10 });
    await settleGestureFrame();
    await moveDrawerDrag(drag, { x: drag.x });
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists({ count: 1 }, "a small, slow movement does not dismiss it");
    assert.dom(document.documentElement).hasClass(/scroll-lock/);
  });

  test("tapping the cloak still closes the hamburger drawer", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const drag = await startDrawerDrag(".header-cloak");
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist("the ordinary tap-to-dismiss behavior is preserved");
    assert.dom(document.documentElement).doesNotHaveClass(/scroll-lock/);
  });

  test("dragging the hamburger drawer back open", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { x: drag.x - 100 });
    await moveDrawerDrag(drag, { x: drag.x + 60 });
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists({ count: 1 }, "it restores the hamburger drawer");
    assert.dom(document.documentElement).hasClass(/scroll-lock/);
  });

  test("dragging the user drawer closed", async function (assert) {
    await visit("/");
    await click("#current-user button");

    assert.dom(document.documentElement).hasClass(/scroll-lock/);

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { x: drag.x + 100 });
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist("it closes the user drawer on a right drag");
    assert.dom(document.documentElement).doesNotHaveClass(/scroll-lock/);
  });
});
