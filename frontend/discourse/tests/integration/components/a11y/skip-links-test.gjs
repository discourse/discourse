import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | a11y/skip-links", function (hooks) {
  setupRenderingTest(hooks);

  test("skip link height does not exceed -75px offset on narrow 320px viewports", async function (assert) {
    const testContainer = document.querySelector("#ember-testing");
    const originalWidth = testContainer?.style.width;

    if (testContainer) {
      testContainer.style.width = "320px";
    }

    try {
      // Russian has the longest translation for this skip link
      const skipLinkText = i18n("skip_to_where_you_left_off_last", {
        post_number: 999,
        locale: "ru",
      });

      await render(
        <template>
          <a
            href="#main-outlet"
            id="skip-link"
            class="skip-link"
          >{{skipLinkText}}</a>
        </template>
      );

      const skipLink = document.querySelector("#skip-link");
      const computedStyle = window.getComputedStyle(skipLink);

      assert.strictEqual(
        computedStyle.top,
        "-75px",
        "skip link has -75px offset on narrow viewport"
      );

      const rect = skipLink.getBoundingClientRect();

      assert.true(
        rect.height <= 75,
        `skip link height (${rect.height}px) must be <= 75px to work with -75px offset`
      );
    } finally {
      if (testContainer) {
        testContainer.style.width = originalWidth || "";
      }
    }
  });

  test("skip links get updated CSS when focused", async function (assert) {
    const skipLinkText = i18n("skip_to_main_content");

    await render(
      <template>
        <a
          href="#main-outlet"
          id="skip-link"
          class="skip-link"
        >{{skipLinkText}}</a>
      </template>
    );

    const skipLink = document.querySelector("#skip-link");

    let computedStyle = window.getComputedStyle(skipLink);
    assert.strictEqual(
      computedStyle.top,
      "-75px",
      "skip link is hidden with -75px offset before focus"
    );

    skipLink.focus();

    computedStyle = window.getComputedStyle(skipLink);
    assert.strictEqual(
      computedStyle.top,
      "0px",
      "skip link gets top: 0 when focused"
    );
  });
});
