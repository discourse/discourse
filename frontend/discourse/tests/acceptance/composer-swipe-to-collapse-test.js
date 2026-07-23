import { click, focus, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

async function swipeDown(selector, { to = 120 } = {}) {
  const at = (y) => ({
    touches: [{ clientX: 0, clientY: y }],
    changedTouches: [{ clientX: 0, clientY: y }],
  });

  await triggerEvent(selector, "touchstart", at(0));
  await triggerEvent(selector, "touchmove", at(to / 2));
  await triggerEvent(selector, "touchmove", at(to));
  // settle at the final position so the release velocity is ~0 and the
  // dismiss decision is distance-based, not a synthetic velocity spike
  await triggerEvent(selector, "touchmove", at(to));
  await triggerEvent(selector, "touchend", {
    touches: [],
    changedTouches: [{ clientX: 0, clientY: to }],
  });
}

acceptance("Composer - swipe to collapse", function (needs) {
  needs.user();
  needs.mobileView();
  needs.settings({ enable_composer_redesign: true });

  test("swiping down anywhere on the composer blurs the editor", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post[data-post-number='1'] button.reply");
    await focus(".d-editor-input");

    assert.dom(".d-editor-textarea-wrapper").hasClass("in-focus");

    await swipeDown(".composer-footer");

    assert.dom(".d-editor-input").isNotFocused();
  });

  test("swiping down from inside the editor blurs it when nothing to scroll", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post[data-post-number='1'] button.reply");
    await focus(".d-editor-input");

    await swipeDown(".d-editor-input");

    assert.dom(".d-editor-input").isNotFocused();
  });

  test("a short drag snaps back and keeps focus", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post[data-post-number='1'] button.reply");
    await focus(".d-editor-input");

    await swipeDown(".composer-footer", { to: 20 });

    assert.dom(".d-editor-input").isFocused();
  });

  test("a swipe is deferred while text is selected", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post[data-post-number='1'] button.reply");
    await focus(".d-editor-input");

    window
      .getSelection()
      .selectAllChildren(
        document.querySelector(".topic-post[data-post-number='1'] .cooked p")
      );

    try {
      await swipeDown(".composer-footer");
      assert.dom(".d-editor-input").isFocused();
    } finally {
      window.getSelection().removeAllRanges();
    }
  });

  test("a dismissing swipe reflows the composer without waiting for the viewport", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post[data-post-number='1'] button.reply");
    await focus(".d-editor-input");

    const docEl = document.documentElement;
    docEl.classList.add("keyboard-visible");

    try {
      await swipeDown(".composer-footer", { to: 20 });
      assert
        .dom(docEl)
        .hasClass("keyboard-visible", "snap-back keeps the keyboard state");

      await swipeDown(".composer-footer");
      assert.dom(docEl).doesNotHaveClass("keyboard-visible");
    } finally {
      docEl.classList.remove("keyboard-visible");
      docEl.style.removeProperty("--composer-vh");
    }
  });
});
