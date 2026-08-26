import { module, test } from "qunit";
import SwipeEvents, {
  shouldDeferSwipeToContent,
  SWIPE_VELOCITY_THRESHOLD,
} from "discourse/lib/swipe-events";

function dispatchTouch(
  element,
  type,
  { x = 0, y = 0, time = 0, touchCount } = {}
) {
  const point = { clientX: x, clientY: y };
  const terminal = type === "touchend" || type === "touchcancel";
  const activeTouches = Array.from(
    { length: touchCount ?? (terminal ? 0 : 1) },
    () => point
  );
  const event = new Event(type, { bubbles: true, cancelable: true });
  Object.defineProperties(event, {
    changedTouches: { value: [point] },
    targetTouches: { value: activeTouches },
    timeStamp: { value: time },
    touches: { value: activeTouches },
  });
  element.dispatchEvent(event);
  return event;
}

module("Unit | Lib | swipe-events | lifecycle", function (hooks) {
  let element;
  let swipeEvents;

  hooks.beforeEach(function () {
    element = document.createElement("div");
    document.getElementById("ember-testing").appendChild(element);
    swipeEvents = new SwipeEvents(element);
    swipeEvents.addTouchListeners();
  });

  hooks.afterEach(function () {
    swipeEvents.removeTouchListeners();
    element.remove();
  });

  test("an accepted swipe can claim the touch and reports release velocity", function (assert) {
    let ended;
    element.addEventListener("swipestart", (event) =>
      event.detail.originalEvent.preventDefault()
    );
    element.addEventListener("swipeend", (event) => (ended = event.detail));

    dispatchTouch(element, "touchstart", { time: 0 });
    const move = dispatchTouch(element, "touchmove", {
      x: 20,
      time: 20,
    });
    dispatchTouch(element, "touchend", { x: 40, time: 40 });

    assert.true(move.defaultPrevented, "the accepted swipe owns the touch");
    assert.strictEqual(ended.deltaX, 40, "release coordinates are included");
    assert.strictEqual(ended.velocityX, 1, "velocity includes the release");
  });

  test("a vetoed swipe leaves the native touch unclaimed", function (assert) {
    element.addEventListener("swipestart", (event) => event.preventDefault());

    dispatchTouch(element, "touchstart", { time: 0 });
    const move = dispatchTouch(element, "touchmove", {
      x: 20,
      time: 20,
    });

    assert.false(move.defaultPrevented, "native scrolling remains available");
  });

  test("release velocity expires while the touch is parked", function (assert) {
    let ended;
    element.addEventListener("swipeend", (event) => (ended = event.detail));

    dispatchTouch(element, "touchstart", { time: 0 });
    dispatchTouch(element, "touchmove", { x: 20, time: 20 });
    dispatchTouch(element, "touchend", { x: 20, time: 200 });

    assert.strictEqual(ended.velocityX, 0, "the old flick is not reused");
  });

  test("an immediate release retains the last movement velocity", function (assert) {
    let ended;
    element.addEventListener("swipeend", (event) => (ended = event.detail));

    dispatchTouch(element, "touchstart", { time: 0 });
    dispatchTouch(element, "touchmove", { x: 20, time: 20 });
    dispatchTouch(element, "touchend", { x: 20, time: 40 });

    assert.strictEqual(ended.velocityX, 1);
  });

  test("stationary movement clears velocity before release", function (assert) {
    let ended;
    element.addEventListener("swipeend", (event) => (ended = event.detail));

    dispatchTouch(element, "touchstart", { time: 0 });
    dispatchTouch(element, "touchmove", { x: 20, time: 20 });
    dispatchTouch(element, "touchmove", { x: 20, time: 30 });
    dispatchTouch(element, "touchend", { x: 20, time: 40 });

    assert.strictEqual(ended.velocityX, 0);
  });

  test("a sub-pixel smear on release is not a flick", function (assert) {
    let ended;
    element.addEventListener("swipeend", (event) => (ended = event.detail));

    // parked long enough for the flick to expire, then lifted with a smear
    dispatchTouch(element, "touchstart", { time: 0 });
    dispatchTouch(element, "touchmove", { x: 20, time: 20 });
    dispatchTouch(element, "touchend", { x: 21, time: 200 });

    assert.true(
      Math.abs(ended.velocityX) < SWIPE_VELOCITY_THRESHOLD,
      "a pixel across a sliver of time does not read as a flick"
    );
  });

  test("a flick released with a smear keeps its velocity", function (assert) {
    let ended;
    element.addEventListener("swipeend", (event) => (ended = event.detail));

    dispatchTouch(element, "touchstart", { time: 0 });
    dispatchTouch(element, "touchmove", { x: 20, time: 20 });
    dispatchTouch(element, "touchend", { x: 21, time: 24 });

    assert.true(
      ended.velocityX >= SWIPE_VELOCITY_THRESHOLD,
      "the lift does not discard the flick that came before it"
    );
  });

  test("touch cancellation cancels rather than ending the swipe", function (assert) {
    element.addEventListener("swipeend", () => assert.step("end"));
    element.addEventListener("swipecancel", () => assert.step("cancel"));

    dispatchTouch(element, "touchstart", { time: 0 });
    dispatchTouch(element, "touchmove", { x: 20, time: 20 });
    dispatchTouch(element, "touchcancel", { x: 20, time: 40 });

    assert.verifySteps(["cancel"], "the interrupted swipe is discarded");
  });

  test("a second touch cancels the swipe and leaves the next gesture clean", function (assert) {
    element.addEventListener("swipecancel", () => assert.step("cancel"));
    element.addEventListener("swipeend", () => assert.step("end"));

    dispatchTouch(element, "touchstart", { time: 0 });
    dispatchTouch(element, "touchmove", { x: 20, time: 20 });
    dispatchTouch(element, "touchstart", { time: 30, touchCount: 2 });
    dispatchTouch(element, "touchend", { time: 40 });

    dispatchTouch(element, "touchstart", { time: 100 });
    dispatchTouch(element, "touchmove", { x: 20, time: 120 });
    dispatchTouch(element, "touchend", { x: 40, time: 140 });

    assert.verifySteps(["cancel", "end"]);
  });
});

function swipeState(direction, target) {
  return {
    direction,
    originalEvent: { target },
    goingDown: () => direction === "down",
    goingUp: () => direction === "up",
  };
}

module("Unit | Lib | swipe-events | shouldDeferSwipeToContent", function () {
  function buildScrollableContent() {
    const container = document.createElement("div");
    const scroller = document.createElement("div");
    scroller.style.overflowY = "scroll";
    scroller.style.height = "50px";
    const content = document.createElement("div");
    content.style.height = "500px";
    scroller.appendChild(content);
    container.appendChild(scroller);
    document.getElementById("ember-testing").appendChild(container);
    return { container, scroller, cleanup: () => container.remove() };
  }

  test("horizontal swipes are always deferred", function (assert) {
    const { container, cleanup } = buildScrollableContent();
    assert.true(
      shouldDeferSwipeToContent(swipeState("left", container), container)
    );
    assert.true(
      shouldDeferSwipeToContent(swipeState("right", container), container)
    );
    cleanup();
  });

  test("swipe down defers when the content is scrolled away from the top", function (assert) {
    const { container, scroller, cleanup } = buildScrollableContent();
    scroller.scrollTop = 30;

    assert.true(
      shouldDeferSwipeToContent(swipeState("down", scroller), container)
    );
    cleanup();
  });

  test("swipe down does not defer at the top edge", function (assert) {
    const { container, scroller, cleanup } = buildScrollableContent();
    scroller.scrollTop = 0;

    assert.false(
      shouldDeferSwipeToContent(swipeState("down", scroller), container)
    );
    cleanup();
  });

  test("swipe up defers while there is room to scroll down", function (assert) {
    const { container, scroller, cleanup } = buildScrollableContent();
    scroller.scrollTop = 0;

    assert.true(
      shouldDeferSwipeToContent(swipeState("up", scroller), container)
    );
    cleanup();
  });

  test("does not defer when nothing between target and container scrolls", function (assert) {
    const container = document.createElement("div");
    const child = document.createElement("div");
    container.appendChild(child);
    document.getElementById("ember-testing").appendChild(container);

    assert.false(
      shouldDeferSwipeToContent(swipeState("down", child), container)
    );
    container.remove();
  });
});
