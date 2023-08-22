import { click, render, settled } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { module, test } from "qunit";

import domFromString from "discourse-common/lib/dom-from-string";
import { generateLightboxMarkup } from "discourse/tests/helpers/lightbox-helpers";
import { hbs } from "ember-cli-htmlbars";
import { setupLightboxes } from "discourse/lib/lightbox";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { SELECTORS } from "discourse/lib/lightbox/constants";

module("Integration | Component | d-lightbox", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders according to state", async function (assert) {
    await render(hbs`<DLightbox />`);

    // lightbox container exists but is not visible
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).exists();
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-visible");
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasAttribute("tabindex", "-1");
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();

    // it is hidden from screen readers
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasAttribute("aria-hidden");

    const container = domFromString(generateLightboxMarkup())[0];
    await setupLightboxes({
      container,
      selector: SELECTORS.DEFAULT_ITEM_SELECTOR,
    });

    const lightboxedElement = container.querySelector(
      SELECTORS.DEFAULT_ITEM_SELECTOR
    );
    await click(lightboxedElement);

    await settled();

    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("is-visible");

    assert
      .dom(SELECTORS.LIGHTBOX_CONTAINER)
      .hasClass(/^(is-vertical|is-horizontal)$/);

    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-zoomed");
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-rotated");
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-fullscreen");

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveAria("hidden");

    // the content is tabbable
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).hasAttribute("tabindex", "0");

    // the content has a document role
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).hasAttribute("role", "document");

    // the content has an aria-labelledby attribute
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).hasAttribute("aria-labelledby");

    assert.strictEqual(
      query(SELECTORS.LIGHTBOX_CONTENT)
        .getAttribute("style")
        .match(/--d-lightbox/g).length > 0,
      true,
      "the content has the correct css variables added"
    );

    // it has focus traps for keyboard navigation
    assert.dom(SELECTORS.FOCUS_TRAP).exists();

    await click(SELECTORS.CLOSE_BUTTON);
    await settled();

    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-visible");
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();

    // it is not tabbable
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasAttribute("tabindex", "-1");

    // it is hidden from screen readers
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasAttribute("aria-hidden");
  });
});
