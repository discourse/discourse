import { click, render, settled } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { module, test } from "qunit";

import domFromString from "discourse-common/lib/dom-from-string";
import { generateLightboxMarkup } from "discourse/tests/helpers/lightbox-helpers";
import { hbs } from "ember-cli-htmlbars";
import { setupLightboxes } from "discourse/lib/lightbox";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const trigger_selector = ".lightbox";
const lightbox_selector = ".d-lightbox";
const lightbox_open_selector = ".d-lightbox__content";

module("Integration | Component | d-lightbox", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders according to state", async function (assert) {
    await render(hbs`<DLightbox />`);

    // lightbox container exists but is not visible
    assert.dom(lightbox_selector).exists();
    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-visible");
    assert.dom(lightbox_selector).hasAttribute("tabindex", "-1");
    assert.dom(lightbox_open_selector).doesNotExist();

    // it is hidden from screen readers
    assert.dom(lightbox_selector).hasAttribute("aria-hidden");

    const container = domFromString(generateLightboxMarkup())[0];
    await setupLightboxes({ container, selector: trigger_selector });

    const lightboxedElement = container.querySelector(trigger_selector);
    await click(lightboxedElement);

    await settled();

    assert.dom(lightbox_selector).hasClass("d-lightbox--is-visible");

    assert
      .dom(lightbox_selector)
      .hasClass(/^(d-lightbox--is-vertical|d-lightbox--is-horizontal)$/);

    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-zoomed");
    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-rotated");
    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-fullscreen");

    assert.dom(lightbox_open_selector).exists();
    assert.dom(lightbox_selector).doesNotHaveAria("hidden");

    // the content is tabbable
    assert.dom(lightbox_open_selector).hasAttribute("tabindex", "0");

    // the content has a document role
    assert.dom(lightbox_open_selector).hasAttribute("role", "document");

    // the content has an aria-labelledby attribute
    assert.dom(lightbox_open_selector).hasAttribute("aria-labelledby");

    assert.strictEqual(
      query(lightbox_open_selector)
        .getAttribute("style")
        .match(/--d-lightbox/g).length,
      8,
      "the content has the corrrect number of css variables"
    );

    // it has focus traps for keyboard navigation
    assert.dom(".d-lightbox__focus-trap").exists();

    await click(".d-lightbox__close-button");
    await settled();

    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-visible");

    assert.dom(lightbox_open_selector).doesNotExist();

    // it is not tabbable
    assert.dom(lightbox_selector).hasAttribute("tabindex", "-1");

    // it is hidden from screen readers
    assert.dom(lightbox_selector).hasAttribute("aria-hidden");
  });
});
