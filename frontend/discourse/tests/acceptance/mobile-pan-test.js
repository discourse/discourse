import { click, find, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { overrideAnimationTimeForTesting } from "discourse/lib/swipe-events";
import { resetSiteDirForTesting } from "discourse/lib/text-direction";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const PANEL_WIDTH_FALLBACK = 340;
const PARKED_RELEASE_MS = 200;

let nextTouchId = 1;

function drawerWidth() {
  return find(".menu-panel").offsetWidth || PANEL_WIDTH_FALLBACK;
}

function dispatchTouch(target, type, swipe) {
  const point = {
    clientX: swipe.x,
    clientY: swipe.y,
    identifier: swipe.identifier,
    target,
  };
  const terminal = type === "touchend" || type === "touchcancel";
  const event = new Event(type, { bubbles: true, cancelable: true });
  Object.defineProperties(event, {
    changedTouches: { value: [point] },
    targetTouches: { value: terminal ? [] : [point] },
    timeStamp: { value: swipe.time },
    touches: { value: terminal ? [] : [point] },
  });
  target.dispatchEvent(event);
  return event;
}

async function startSwipe(targetSelector, { wait = true } = {}) {
  const target = find(targetSelector);
  const swipe = {
    identifier: nextTouchId++,
    target,
    time: 1000,
    x: 200,
    y: 200,
  };

  target.dispatchEvent(
    new PointerEvent("pointerdown", {
      bubbles: true,
      cancelable: true,
      clientX: swipe.x,
      clientY: swipe.y,
      pointerId: swipe.identifier,
      pointerType: "touch",
    })
  );
  swipe.startEvent = dispatchTouch(target, "touchstart", swipe);
  if (wait) {
    await settled();
  }
  return swipe;
}

async function moveSwipe(swipe, { x = 0, y = 0, afterMs = 16 }) {
  swipe.x += x;
  swipe.y += y;
  swipe.time += afterMs;
  const event = dispatchTouch(swipe.target, "touchmove", swipe);
  await settled();
  return event;
}

function releaseSwipe(swipe, { afterMs = 16 } = {}) {
  swipe.time += afterMs;
  return dispatchTouch(swipe.target, "touchend", swipe);
}

async function endSwipe(swipe, options) {
  releaseSwipe(swipe, options);
  await settled();
}

async function openHamburgerDrawer() {
  await visit("/");
  await click(".hamburger-dropdown button");
}

function drawerTranslateX() {
  const { transform } = window.getComputedStyle(find(".menu-panel"));
  return transform === "none"
    ? 0
    : Math.round(new DOMMatrixReadOnly(transform).m41);
}

acceptance("Mobile - menu drawer swipes", function (needs) {
  needs.mobileView();
  needs.user();

  needs.hooks.afterEach(() => overrideAnimationTimeForTesting());

  test("distance closes the hamburger drawer", async function (assert) {
    await openHamburgerDrawer();

    const swipe = await startSwipe(".panel-body");
    await moveSwipe(swipe, { x: -drawerWidth() / 2, afterMs: 400 });
    await endSwipe(swipe, { afterMs: PARKED_RELEASE_MS });
    assert.dom(".panel-body").doesNotExist("distance closes the drawer");
  });

  test("velocity closes the hamburger drawer", async function (assert) {
    await openHamburgerDrawer();

    const swipe = await startSwipe(".panel-body");
    await moveSwipe(swipe, { x: -40 });
    await endSwipe(swipe);
    assert.dom(".panel-body").doesNotExist("a short flick closes the drawer");
  });

  test("a small movement leaves the drawer open", async function (assert) {
    await openHamburgerDrawer();

    const swipe = await startSwipe(".panel-body");
    await moveSwipe(swipe, { x: -8, afterMs: 400 });
    await endSwipe(swipe, { afterMs: PARKED_RELEASE_MS });
    assert.dom(".panel-body").exists("a small movement is not a dismissal");
    assert.strictEqual(drawerTranslateX(), 0, "the drawer settles open");
  });

  test("a parked flick leaves the drawer open", async function (assert) {
    await openHamburgerDrawer();

    const swipe = await startSwipe(".panel-body");
    await moveSwipe(swipe, { x: -40 });
    await endSwipe(swipe, { afterMs: PARKED_RELEASE_MS });
    assert.dom(".panel-body").exists("a parked flick loses its velocity");
    assert.strictEqual(drawerTranslateX(), 0, "the drawer settles open again");
  });

  test("a cloak tap closes through the drawer path", async function (assert) {
    await openHamburgerDrawer();

    const swipe = await startSwipe(".header-cloak");
    assert
      .dom(".panel-body")
      .exists("the outside handler does not close on press");
    await endSwipe(swipe);
    assert.dom(".panel-body").doesNotExist("a cloak tap closes the drawer");
  });

  test("cloak jitter closes through the drawer path", async function (assert) {
    await openHamburgerDrawer();

    const swipe = await startSwipe(".header-cloak");
    await moveSwipe(swipe, { y: 8, afterMs: 400 });
    await endSwipe(swipe, { afterMs: PARKED_RELEASE_MS });
    assert.dom(".panel-body").doesNotExist("cloak jitter still closes it");
  });

  test("pulling the drawer open from the cloak keeps it open", async function (assert) {
    await openHamburgerDrawer();

    const swipe = await startSwipe(".header-cloak");
    await moveSwipe(swipe, { x: drawerWidth() / 3, afterMs: 400 });
    await endSwipe(swipe, { afterMs: PARKED_RELEASE_MS });

    assert.dom(".panel-body").exists("a deliberate opening pull wins");
    assert.strictEqual(drawerTranslateX(), 0, "the overdrag settles open");
  });

  test("vertical movement in the panel remains native", async function (assert) {
    await openHamburgerDrawer();

    const swipe = await startSwipe(".panel-body");
    const move = await moveSwipe(swipe, { y: 20 });
    await endSwipe(swipe);

    assert.false(move.defaultPrevented, "the page keeps the vertical touch");
    assert.dom(".panel-body").exists("vertical movement does not dismiss");
  });

  test("taps on panel links remain native", async function (assert) {
    await openHamburgerDrawer();

    const swipe = await startSwipe(".panel-body a");
    const end = releaseSwipe(swipe);
    await settled();

    assert.false(swipe.startEvent.defaultPrevented, "touchstart is preserved");
    assert.false(end.defaultPrevented, "touchend is preserved");
    assert.dom(".panel-body").exists("the tap does not dismiss the drawer");
  });

  test("the close threshold uses the rendered drawer width", async function (assert) {
    const style = document.createElement("style");
    style.textContent =
      ".menu-panel.slide-in { width: 450px !important; max-width: 450px !important; }";
    document.head.appendChild(style);

    try {
      await openHamburgerDrawer();
      assert.strictEqual(
        Math.round(drawerWidth()),
        450,
        "the test drawer renders at the requested width"
      );
      assert.strictEqual(drawerTranslateX(), 0, "the drawer starts open");
      const swipe = await startSwipe(".panel-body");
      await moveSwipe(swipe, { x: -100, afterMs: 400 });
      assert.strictEqual(
        drawerTranslateX(),
        -100,
        "the drawer follows the touch"
      );
      await endSwipe(swipe, { afterMs: PARKED_RELEASE_MS });
      assert.dom(".panel-body").exists("less than a quarter stays open");
    } finally {
      style.remove();
    }
  });

  test("a settling drawer can be caught and continued", async function (assert) {
    await openHamburgerDrawer();

    const swipe = await startSwipe(".panel-body");
    await moveSwipe(swipe, { x: -drawerWidth() / 5, afterMs: 400 });
    const releasedAt = drawerTranslateX();

    overrideAnimationTimeForTesting(1000);
    releaseSwipe(swipe, { afterMs: PARKED_RELEASE_MS });
    const caught = await startSwipe(".panel-body", { wait: false });
    overrideAnimationTimeForTesting();

    assert.strictEqual(
      find(".menu-panel").getAnimations().length,
      0,
      "the press stops the settle"
    );
    assert.strictEqual(
      drawerTranslateX(),
      releasedAt,
      "the drawer is caught where it was"
    );

    await moveSwipe(caught, { x: -12, afterMs: 400 });
    assert.strictEqual(
      drawerTranslateX(),
      releasedAt - 12,
      "movement continues from the caught position"
    );
    await endSwipe(caught, { afterMs: PARKED_RELEASE_MS });
  });

  test("the user drawer closes toward its edge", async function (assert) {
    await visit("/");
    await click("#current-user button");

    const swipe = await startSwipe(".panel-body");
    await moveSwipe(swipe, { x: drawerWidth() / 2, afterMs: 400 });
    await endSwipe(swipe, { afterMs: PARKED_RELEASE_MS });

    assert.dom(".panel-body").doesNotExist("the user drawer closes right");
  });

  test("the user drawer closes toward its edge under RTL", async function (assert) {
    await visit("/");
    await click("#current-user button");
    document.documentElement.classList.add("rtl");
    resetSiteDirForTesting();

    try {
      const swipe = await startSwipe(".panel-body");
      await moveSwipe(swipe, { x: -drawerWidth() / 2, afterMs: 400 });
      await endSwipe(swipe, { afterMs: PARKED_RELEASE_MS });
      assert.dom(".panel-body").doesNotExist("the RTL user drawer closes left");
    } finally {
      document.documentElement.classList.remove("rtl");
      resetSiteDirForTesting();
    }
  });
});
