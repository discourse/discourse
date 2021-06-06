import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";

async function triggerSwipeStart(touchTarget) {
  const touchStart = {
    touchTarget: touchTarget,
    x: touchTarget.getBoundingClientRect().x / 2 + touchTarget.offsetWidth / 4,
    y: touchTarget.getBoundingClientRect().y / 2 + touchTarget.offsetHeight / 4,
  };
  const touch = new Touch({
    identifier: "test",
    target: touchTarget,
    clientX: touchStart.x,
    clientY: touchStart.y,
  });
  await triggerEvent(touchTarget, "touchstart", {
    touches: [touch],
    targetTouches: [touch],
  });
  return touchStart;
}
async function triggerSwipeMove({ x, y, touchTarget }) {
  const touch = new Touch({
    identifier: "test",
    target: touchTarget,
    clientX: x,
    clientY: y,
  });
  await triggerEvent(touchTarget, "touchmove", {
    touches: [touch],
    targetTouches: [touch],
  });
}
async function triggerSwipeEnd({ x, y, touchTarget }) {
  const touch = new Touch({
    identifier: "test",
    target: touchTarget,
    clientX: x,
    clientY: y,
  });
  await triggerEvent(touchTarget, "touchend", {
    touches: [touch],
    targetTouches: [touch],
  });
}

acceptance("Mobile - menu swipes", function (needs) {
  needs.mobileView();
  needs.user();
  test("swipe to close hamburger", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown");

    const touchTarget = document.querySelector(".panel-body");
    let swipe = await triggerSwipeStart(touchTarget);
    swipe.x -= 20;
    await triggerSwipeMove(swipe);
    await triggerSwipeEnd(swipe);

    assert.ok(
      queryAll(".panel-body").length === 0,
      "it should close hamburger on a left swipe"
    );
  });

  test("swipe back and flick to re-open hamburger", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown");

    const touchTarget = document.querySelector(".panel-body");
    let swipe = await triggerSwipeStart(touchTarget);
    swipe.x -= 100;
    await triggerSwipeMove(swipe);
    swipe.x += 20;
    await triggerSwipeMove(swipe);
    await triggerSwipeEnd(swipe);

    assert.ok(
      queryAll(".panel-body").length === 1,
      "it should re-open hamburger on a right swipe"
    );
  });

  test("swipe to user menu", async function (assert) {
    await visit("/");
    await click("#current-user");

    const touchTarget = document.querySelector(".panel-body");
    let swipe = await triggerSwipeStart(touchTarget);
    swipe.x += 20;
    await triggerSwipeMove(swipe);
    await triggerSwipeEnd(swipe);

    assert.ok(
      queryAll(".panel-body").length === 0,
      "it should close user menu on a left swipe"
    );
  });
});
