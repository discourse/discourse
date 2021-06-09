import {
  acceptance,
  count,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";

async function triggerSwipeStart(touchTarget) {
  // some tests are shown in a zoom viewport.
  // boundingClientRect is affected by the zoom and need to be multiplied by the zoom effect.
  // EG: if the element has a zoom of 50%, this DOUBLES the x and y positions and offsets.
  // The numbers you get from getBoundingClientRect are seen as twice as large... however, the
  // touch input still deals with the base inputs, not doubled. This allows us to convert for those environments.
  let zoom = parseFloat(
    window.getComputedStyle(document.querySelector("#ember-testing")).zoom || 1
  );

  // Other tests are shown in a transformed viewport, and this is a multiple for the offsets
  let scale = parseFloat(
    window
      .getComputedStyle(document.querySelector("#ember-testing"))
      .transform.replace("matrix(", "") || 1
  );

  const touchStart = {
    touchTarget: touchTarget,
    x:
      zoom *
      (touchTarget.getBoundingClientRect().x +
        (scale * touchTarget.offsetWidth) / 2),
    y:
      zoom *
      (touchTarget.getBoundingClientRect().y +
        (scale * touchTarget.offsetHeight) / 2),
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
      !exists(".panel-body"),
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

    assert.equal(
      count(".panel-body"),
      1,
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
      !exists(".panel-body"),
      "it should close user menu on a left swipe"
    );
  });
});
