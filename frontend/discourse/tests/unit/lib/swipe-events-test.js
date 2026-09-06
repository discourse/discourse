import { module, test } from "qunit";
import { shouldDeferSwipeToContent } from "discourse/lib/swipe-events";

function swipeState(direction, target) {
  return {
    direction,
    originalEvent: { target },
    goingDown: () => direction === "down",
    goingUp: () => direction === "up",
  };
}

module("Unit | Lib | swipe-events | shouldDeferSwipeToContent", function () {
  // real elements so getComputedStyle and scroll metrics behave like the browser
  function build() {
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
    const { container, cleanup } = build();
    assert.true(
      shouldDeferSwipeToContent(swipeState("left", container), container)
    );
    assert.true(
      shouldDeferSwipeToContent(swipeState("right", container), container)
    );
    cleanup();
  });

  test("swipe down defers when the content is scrolled away from the top", function (assert) {
    const { container, scroller, cleanup } = build();
    scroller.scrollTop = 30;

    assert.true(
      shouldDeferSwipeToContent(swipeState("down", scroller), container)
    );
    cleanup();
  });

  test("swipe down does not defer at the top edge", function (assert) {
    const { container, scroller, cleanup } = build();
    scroller.scrollTop = 0;

    assert.false(
      shouldDeferSwipeToContent(swipeState("down", scroller), container)
    );
    cleanup();
  });

  test("swipe up defers while there is room to scroll down", function (assert) {
    const { container, scroller, cleanup } = build();
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
