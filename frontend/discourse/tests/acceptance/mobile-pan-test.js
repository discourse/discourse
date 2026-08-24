import { click, find, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { overrideAnimationTimeForTesting } from "discourse/lib/swipe-events";
import { resetSiteDirForTesting } from "discourse/lib/text-direction";
import Site from "discourse/models/site";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  stubPointerCapture,
  stubSharedPointerCapture,
} from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";

const PANEL_WIDTH_FALLBACK = 340;
const JITTER_PX = 8;
const PARKED_RELEASE_MS = 250;

let nextPointerId = 1;

function drawerWidth() {
  return (
    find(".menu-panel").getBoundingClientRect().width || PANEL_WIDTH_FALLBACK
  );
}

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
  if (target !== gestureSurface) {
    stubPointerCapture(target);
  }

  dispatchPointerEvent(target, "pointerdown", drag);
  await settled();

  return drag;
}

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

async function endParkedDrawerDrag(drag) {
  await endDrawerDrag(drag, { afterMs: PARKED_RELEASE_MS });
}

function drawerTranslateX() {
  const { transform } = window.getComputedStyle(find(".menu-panel"));
  return transform === "none"
    ? 0
    : Math.round(new DOMMatrixReadOnly(transform).m41);
}

// without the gesture, the outside-press handler closes the drawer at the press
// and every later assertion passes vacuously
function assertPressAloneKeptDrawer(assert) {
  assert
    .dom(".panel-body")
    .exists({ count: 1 }, "the press alone does not dismiss the drawer");
}

async function openHamburgerDrawer() {
  await visit("/");
  await click(".hamburger-dropdown button");
}

async function cancelDrawerDrag(drag, { afterMs = 16 } = {}) {
  drag.time += afterMs;
  dispatchPointerEvent(drag.gestureSurface, "pointercancel", drag);
  await settled();
}

acceptance("Mobile - menu drawer gestures", function (needs) {
  needs.mobileView();
  needs.user();

  // a test dying mid-settle must not leave the override active for later tests
  needs.hooks.afterEach(() => overrideAnimationTimeForTesting());

  test("a drag past the distance threshold closes the hamburger drawer", async function (assert) {
    await openHamburgerDrawer();

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
    await openHamburgerDrawer();

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: -drawerWidth() / 10, afterMs: 16 });
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist("a short, fast movement closes it on velocity alone");
  });

  test("parking the pointer after a flick leaves the hamburger drawer open", async function (assert) {
    await openHamburgerDrawer();

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: -drawerWidth() / 10, afterMs: 16 });
    await endParkedDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists(
        { count: 1 },
        "the flick's velocity expires while the pointer is held still, so the release is not read as a flick"
      );
    assert.strictEqual(
      drawerTranslateX(),
      0,
      "and it settles rather than staying where the pointer left it"
    );
    assert.dom(document.documentElement).hasClass(/scroll-lock/);
  });

  test("dragging the hamburger drawer back open", async function (assert) {
    await openHamburgerDrawer();

    const width = drawerWidth();
    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: -width / 2, afterMs: 400 });

    assert
      .dom(".panel-body")
      .hasClass(/scroll-lock/, "the panel's content is locked while it drags");

    await moveDrawerDrag(drag, { by: width / 2 - JITTER_PX, afterMs: 400 });
    await endParkedDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists({ count: 1 }, "it restores the hamburger drawer");
    assert.dom(document.documentElement).hasClass(/scroll-lock/);
    assert.strictEqual(
      drawerTranslateX(),
      0,
      "and it settles rather than staying where the pointer left it"
    );
    assert
      .dom(".panel-body")
      .doesNotHaveClass(
        /scroll-lock/,
        "the panel's own scroll lock is released with the gesture"
      );
  });

  test("tapping the cloak closes the hamburger drawer", async function (assert) {
    await openHamburgerDrawer();

    const drag = await startDrawerDrag(".header-cloak");
    assertPressAloneKeptDrawer(assert);
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist("the ordinary tap-to-dismiss behavior is preserved");
    assert.dom(document.documentElement).doesNotHaveClass(/scroll-lock/);
  });

  test("a jittery tap on the cloak still closes the hamburger drawer", async function (assert) {
    await openHamburgerDrawer();

    const drag = await startDrawerDrag(".header-cloak");
    assertPressAloneKeptDrawer(assert);
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
    await openHamburgerDrawer();

    const drag = await startDrawerDrag(".header-cloak");
    assertPressAloneKeptDrawer(assert);
    await moveDrawerDrag(drag, { by: drawerWidth() / 4, afterMs: 400 });
    await endParkedDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists(
        { count: 1 },
        "a deliberate pull in the opening direction is the one cloak gesture that does not dismiss"
      );
    assert.strictEqual(drawerTranslateX(), 0, "and the overdrag is settled");
  });

  test("catching the drawer while it settles closed keeps it open", async function (assert) {
    await openHamburgerDrawer();

    const width = drawerWidth();
    const closing = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(closing, { by: -width / 2, afterMs: 400 });

    releaseDrawerDrag(closing, { afterMs: 400 });

    const caught = await startDrawerDrag(".panel-body");
    // zero-duration settles land instantly, so the drawer is caught fully closed
    await moveDrawerDrag(caught, { by: width, afterMs: 400 });
    await endParkedDrawerDrag(caught);

    assert
      .dom(".panel-body")
      .exists(
        { count: 1 },
        "the settling close does not commit over the gesture that caught the drawer"
      );
    assert.strictEqual(
      drawerTranslateX(),
      0,
      "and it settles rather than staying where the pointer left it"
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

  test("a cloak gesture the browser claims still closes the drawer", async function (assert) {
    await openHamburgerDrawer();

    const drag = await startDrawerDrag(".header-cloak");
    assertPressAloneKeptDrawer(assert);
    await moveDrawerDrag(drag, { by: -JITTER_PX, afterMs: 400 });
    await cancelDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .doesNotExist(
        "a press outside the drawer dismisses it however the gesture ends, since the outside-press handler it displaced will not fire"
      );
    assert.dom(document.documentElement).doesNotHaveClass(/scroll-lock/);
  });

  test("a cloak gesture pulling the drawer open survives a claim", async function (assert) {
    await openHamburgerDrawer();

    const drag = await startDrawerDrag(".header-cloak");
    assertPressAloneKeptDrawer(assert);
    await moveDrawerDrag(drag, { by: drawerWidth() / 4, afterMs: 400 });
    await cancelDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists(
        { count: 1 },
        "a deliberate pull the other way is still not a dismissal"
      );
    assert.strictEqual(
      drawerTranslateX(),
      0,
      "and it settles back rather than staying where the overdrag left it"
    );
  });

  test("a reversal sharing a timestamp does not close the drawer", async function (assert) {
    await openHamburgerDrawer();

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: -drawerWidth() / 10, afterMs: 16 });
    await moveDrawerDrag(drag, { by: JITTER_PX * 2, afterMs: 0 });
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists(
        { count: 1 },
        "an untimeable sample leaves the decision to distance, which this drag never covers"
      );
    assert.strictEqual(
      drawerTranslateX(),
      0,
      "and it settles rather than staying where the pointer left it"
    );
    assert.dom(document.documentElement).hasClass(/scroll-lock/);
  });

  test("the user drawer closes toward its own edge under RTL", async function (assert) {
    await visit("/");
    await click("#current-user button");

    // rtlcss flips the anchoring at build time only, so this covers just the
    // direction logic; siteDir memoizes off the class
    document.documentElement.classList.add("rtl");
    resetSiteDirForTesting();

    try {
      const drag = await startDrawerDrag(".panel-body");
      await moveDrawerDrag(drag, { by: -drawerWidth() / 2, afterMs: 400 });
      await endParkedDrawerDrag(drag);

      assert
        .dom(".panel-body")
        .doesNotExist(
          "under RTL the user drawer is the left menu, so dragging left dismisses it"
        );
    } finally {
      document.documentElement.classList.remove("rtl");
      resetSiteDirForTesting();
    }
  });

  test("a correction after overdragging does not dismiss the drawer", async function (assert) {
    await openHamburgerDrawer();

    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: drawerWidth() * 0.6, afterMs: 400 });
    await moveDrawerDrag(drag, { by: -JITTER_PX, afterMs: 16 });
    await endDrawerDrag(drag);

    assert
      .dom(".panel-body")
      .exists(
        { count: 1 },
        "a flick's velocity cannot close a drawer the gesture has net pulled open"
      );
    assert.strictEqual(
      drawerTranslateX(),
      0,
      "and the rubber-banding settles back"
    );
  });

  test("catching a settling drawer carries on from where it is", async function (assert) {
    await openHamburgerDrawer();

    const width = drawerWidth();
    const panel = find(".menu-panel");
    const cloak = find(".header-cloak");
    const drag = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(drag, { by: -width / 5, afterMs: 400 });
    const pulledTo = drawerTranslateX();

    // a real duration keeps the settle in flight for the press to catch
    overrideAnimationTimeForTesting(1_000);
    releaseDrawerDrag(drag, { afterMs: PARKED_RELEASE_MS });
    const caught = await startDrawerDrag(".panel-body");
    overrideAnimationTimeForTesting();

    assert.strictEqual(
      panel.getAnimations().length + cloak.getAnimations().length,
      0,
      "the press cancels the settle animations the drawer was running"
    );
    assert.strictEqual(
      drawerTranslateX(),
      pulledTo,
      "the drawer is caught where the settle had it, not snapped to open"
    );

    await moveDrawerDrag(caught, { by: -JITTER_PX, afterMs: 400 });

    assert.strictEqual(
      drawerTranslateX(),
      pulledTo - JITTER_PX,
      "the drag moves the drawer on from there"
    );
    assert.strictEqual(
      panel.getAnimations().length,
      0,
      "previews write styles rather than stacking animations per move"
    );

    await endParkedDrawerDrag(caught);
  });

  test("a second pointer does not take the drawer from the first", async function (assert) {
    await openHamburgerDrawer();

    const width = drawerWidth();
    const held = await startDrawerDrag(".panel-body");
    await moveDrawerDrag(held, { by: -width / 4, afterMs: 400 });
    const caughtAt = drawerTranslateX();

    const second = await startDrawerDrag(".header-cloak");
    await moveDrawerDrag(second, { by: width / 4, afterMs: 400 });

    assert.strictEqual(
      drawerTranslateX(),
      caughtAt,
      "the second pointer is refused rather than overwriting the gesture in flight"
    );

    await endDrawerDrag(second);
    await endParkedDrawerDrag(held);
  });

  test("a press inside the panel hands the capture to the pressed control", async function (assert) {
    await openHamburgerDrawer();

    const { ownerOf } = stubSharedPointerCapture([
      ".menu-panel",
      ".panel-body",
    ]);
    const drag = {
      gestureSurface: find(".menu-panel"),
      pointerId: nextPointerId++,
      x: 200,
      y: 200,
      time: 1000,
    };

    dispatchPointerEvent(find(".panel-body"), "pointerdown", drag);
    await settled();

    assert
      .dom(ownerOf(drag.pointerId))
      .hasClass(
        "panel-body",
        "the pressed node keeps the capture, not the panel"
      );

    await endDrawerDrag(drag);
  });

  test("a press inside the panel is left uncancelled, a press on the cloak is not", async function (assert) {
    await openHamburgerDrawer();

    const prevented = {};
    const record = (surface) => (event) =>
      (prevented[surface] = event.defaultPrevented);
    const panel = find(".menu-panel");
    const cloak = find(".header-cloak");
    const recordPanel = record("panel");
    const recordCloak = record("cloak");
    panel.addEventListener("pointerdown", recordPanel);
    cloak.addEventListener("pointerdown", recordCloak);

    let panelDragEngaged;
    try {
      const panelDrag = await startDrawerDrag(".panel-body");
      await moveDrawerDrag(panelDrag, { by: -JITTER_PX * 3, afterMs: 400 });
      panelDragEngaged = drawerTranslateX() !== 0;
      await endParkedDrawerDrag(panelDrag);
      await endDrawerDrag(await startDrawerDrag(".header-cloak"));
    } finally {
      panel.removeEventListener("pointerdown", recordPanel);
      cloak.removeEventListener("pointerdown", recordCloak);
    }

    assert.true(
      panelDragEngaged,
      "the panel gesture exists, so the uncancelled press below is its doing rather than its absence"
    );
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

acceptance("Narrow desktop - menu drawer gestures", function (needs) {
  needs.user();

  test("dragging the hamburger drawer closed", async function (assert) {
    await visit("/");
    Site.current().set("narrowDesktopView", true);

    try {
      await click(".btn-sidebar-toggle");

      const drag = await startDrawerDrag(".panel-body");
      await moveDrawerDrag(drag, { by: -drawerWidth() / 2 });
      await endParkedDrawerDrag(drag);

      assert
        .dom(".panel-body")
        .doesNotExist("every slide-in drawer drags, not only the mobile one");
    } finally {
      Site.current().set("narrowDesktopView", false);
    }
  });
});
