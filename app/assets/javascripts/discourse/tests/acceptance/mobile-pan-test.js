import {
  acceptance,
  chromeTest,
  count,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import { click, triggerEvent, visit } from "@ember/test-helpers";
import { setupApplicationTest as EMBER_CLI_ENV } from "ember-qunit";

async function triggerSwipeStart(touchTarget) {
  const touchStart = {
    touchTarget,
    x: touchTarget.getBoundingClientRect().x + touchTarget.offsetWidth / 2,
    y: touchTarget.getBoundingClientRect().y + touchTarget.offsetHeight / 2,
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
  if (!EMBER_CLI_ENV) {
    return; // helpers not available in legacy env
  }

  needs.mobileView();
  needs.user();

  // new Touch() isn't available in Firefox
  chromeTest("swipe to close hamburger", async function (assert) {
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

  chromeTest(
    "swipe back and flick to re-open hamburger",
    async function (assert) {
      await visit("/");
      await click(".hamburger-dropdown");

      const touchTarget = document.querySelector(".panel-body");
      let swipe = await triggerSwipeStart(touchTarget);
      swipe.x -= 100;
      await triggerSwipeMove(swipe);
      swipe.x += 20;
      await triggerSwipeMove(swipe);
      await triggerSwipeEnd(swipe);

      assert.strictEqual(
        count(".panel-body"),
        1,
        "it should re-open hamburger on a right swipe"
      );
    }
  );

  chromeTest("swipe to user menu", async function (assert) {
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
