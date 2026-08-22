import { click, find, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { DRAWER_VELOCITY_EXPIRY_MS } from "discourse/components/glimmer-site-header";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";

const PANEL_WIDTH_FALLBACK = 340;
// Past the gesture's 5px threshold, so the drag engages, but far under the
// quarter-width a closing drag needs — leaving only the rule under test to
// decide the outcome.
const JITTER_PX = 8;

let nextPointerId = 1;

function drawerWidth() {
  return (
    find(".menu-panel").getBoundingClientRect().width || PANEL_WIDTH_FALLBACK
  );
}

/**
 * Dispatches a pointer event with a timestamp the test chooses.
 *
 * `Event.timeStamp` is a prototype accessor, so an own property shadows it. The
 * gesture derives velocity from it, and the real timestamp of a synthetic event
 * is whatever the test run happened to cost — which is what made the earlier
 * version of this suite depend on wall-clock spacing.
 */
function dispatchPointerEvent(target, type, drag) {
  const event = new PointerEvent(type, {
    bubbles: true,
    cancelable: true,
    button: 0,
    pointerId: drag.pointerId,
    clientX: drag.x,
    clientY: drag.y,
  });
  Object.defineProperty(event, "timeStamp", { value: drag.time });
  target.dispatchEvent(event);
}

async function startDrawerDrag(targetSelector) {
  const target = find(targetSelector);
  const gestureSurface = target.closest(".menu-panel.slide-in, .header-cloak");
  const drag = {
    gestureSurface,
    pointerId: nextPointerId++,
    x: 200,
    y: 200,
    time: 1000,
  };

  stubPointerCapture(gestureSurface);
  dispatchPointerEvent(target, "pointerdown", drag);
  await settled();

  return drag;
}

/**
 * Moves the pointer `by` pixels horizontally, `afterMs` after the previous
 * event. Together those fix the velocity the gesture reads: a small `afterMs` is
 * a flick, a large one a deliberate drag.
 */
async function moveDrawerDrag(drag, { by, afterMs = 16 }) {
  drag.x += by;
  drag.time += afterMs;

  dispatchPointerEvent(drag.gestureSurface, "pointermove", drag);
  await settled();
}

function releaseDrawerDrag(drag, { afterMs = 16 } = {}) {
  drag.time += afterMs;
  dispatchPointerEvent(drag.gestureSurface, "pointerup", drag);
}

async function endDrawerDrag(drag, options) {
  releaseDrawerDrag(drag, options);
  await settled();
}

/** A release the gesture must read as a parked pointer rather than a flick. */
async function endParkedDrawerDrag(drag) {
  await endDrawerDrag(drag, { afterMs: DRAWER_VELOCITY_EXPIRY_MS + 1 });
}

acceptance("Mobile - menu drawer gestures", function (needs) {
  needs.mobileView();
  needs.user();

  test("a drag past the distance threshold closes the hamburger drawer", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    assert.dom(document.documentElement).hasClass(/scroll-lock/);

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: -drawerWidth() / 2 });
    await endParkedDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist("half the drawer's width closes it on distance alone");
    assert.dom(document.documentElement).doesNotHaveClass(/scroll-lock/);
  });

  test("a flick closes the hamburger drawer", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: -drawerWidth() / 10, afterMs: 16 });
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist("a short, fast movement closes it on velocity alone");
  });

  test("parking the pointer after a flick leaves the hamburger drawer open", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: -drawerWidth() / 10, afterMs: 16 });
    await endParkedDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists(
        { count: 1 },
        "the flick's velocity expires while the pointer is held still, so the release is not read as a flick"
      );
    assert.dom(document.documentElement).hasClass(/scroll-lock/);
  });

  test("dragging the hamburger drawer back open", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const width = drawerWidth();
    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: -width / 2, afterMs: 400 });
    await moveDrawerDrag(drag, { by: width / 2 - JITTER_PX, afterMs: 400 });
    await endParkedDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists({ count: 1 }, "it restores the hamburger drawer");
    assert.dom(document.documentElement).hasClass(/scroll-lock/);
    assert
      .dom(".panel-body")
      .doesNotHaveClass(
        /scroll-lock/,
        "the panel's own scroll lock is released with the gesture"
      );
  });

  test("a short slow drag settles the hamburger drawer open", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: -JITTER_PX, afterMs: 400 });
    await endParkedDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists({ count: 1 }, "a small, slow movement does not dismiss it");
    assert.dom(document.documentElement).hasClass(/scroll-lock/);
  });

  test("tapping the cloak closes the hamburger drawer", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const drag = await startDrawerDrag(".header-cloak");
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist("the ordinary tap-to-dismiss behavior is preserved");
    assert.dom(document.documentElement).doesNotHaveClass(/scroll-lock/);
  });

  test("a jittery tap on the cloak still closes the hamburger drawer", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const drag = await startDrawerDrag(".header-cloak");
    await moveDrawerDrag(drag, { by: -JITTER_PX, afterMs: 400 });
    await endParkedDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist(
        "finger jitter engages the drag but must not strand the drawer open"
      );
    assert.dom(document.documentElement).doesNotHaveClass(/scroll-lock/);
  });

  test("dragging the drawer open from the cloak keeps it open", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const drag = await startDrawerDrag(".header-cloak");
    await moveDrawerDrag(drag, { by: drawerWidth() / 4, afterMs: 400 });
    await endParkedDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists(
        { count: 1 },
        "a deliberate pull in the opening direction is the one cloak gesture that does not dismiss"
      );
  });

  test("dragging from the cloak closes the hamburger drawer", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const drag = await startDrawerDrag(".header-cloak");
    await moveDrawerDrag(drag, { by: -drawerWidth() / 2, afterMs: 400 });
    await endParkedDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist("the cloak drag closes instead of reopening the drawer");
    assert.dom(document.documentElement).doesNotHaveClass(/scroll-lock/);
  });

  test("catching the drawer while it settles closed keeps it open", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    const width = drawerWidth();
    const closing = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(closing, { by: -width / 2, afterMs: 400 });

    // Deliberately unsettled: the close commits on a later microtask, and the
    // point is that a gesture arriving before it claims the drawer back.
    releaseDrawerDrag(closing, { afterMs: 400 });

    const caught = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(caught, { by: width / 2, afterMs: 400 });
    await endParkedDrawerDrag(caught);

    assert
      .dom(".panel-body")
      .exists(
        { count: 1 },
        "the settling close does not commit over the gesture that caught the drawer"
      );
    assert.dom(document.documentElement).hasClass(/scroll-lock/);
  });

  test("dragging the user drawer closed", async function (assert) {
    await visit("/");
    await click("#current-user button");

    assert.dom(document.documentElement).hasClass(/scroll-lock/);

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: drawerWidth() / 2 });
    await endParkedDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist("it closes the user drawer on a right drag");
    assert.dom(document.documentElement).doesNotHaveClass(/scroll-lock/);
  });

  test("a press inside the panel is left uncancelled, a press on the cloak is not", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown button");

    // Recorded on the surfaces themselves: each gesture registered its listener
    // first, so these run after it, and the cloak stops its press from reaching
    // any ancestor.
    const prevented = {};
    const record = (surface) => (event) =>
      (prevented[surface] = event.defaultPrevented);
    const panel = find(".menu-panel");
    const cloak = find(".header-cloak");
    const recordPanel = record("panel");
    const recordCloak = record("cloak");
    panel.addEventListener("pointerdown", recordPanel);
    cloak.addEventListener("pointerdown", recordCloak);

    try {
      await endDrawerDrag(await startDrawerDrag(".panel-body"));
      await endDrawerDrag(await startDrawerDrag(".header-cloak"));
    } finally {
      panel.removeEventListener("pointerdown", recordPanel);
      cloak.removeEventListener("pointerdown", recordCloak);
    }

    assert.false(
      prevented.panel,
      "the panel keeps the compatibility mousedown its controls need for focus and text selection"
    );
    assert.true(
      prevented.cloak,
      "the cloak carries nothing to press, so its gesture still suppresses one"
    );
  });
});
