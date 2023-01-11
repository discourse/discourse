import { click, render, settled } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { module, test } from "qunit";

import domFromString from "discourse-common/lib/dom-from-string";
import { generateLightboxMarkup } from "discourse/tests/helpers/lightbox-helpers";
import { hbs } from "ember-cli-htmlbars";
import { setupLightboxes } from "discourse/lib/lightbox";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | d-lightbox", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders according to state", async function (assert) {
    await render(hbs`<DLightbox />`);

    assert.ok(exists("[data-lightbox-element]"), "it renders");

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-visible"
      ),
      "it is hidden by default"
    );

    assert.notOk(exists("[data-lightbox-content]"), "it has no content");

    assert.strictEqual(
      query("[data-lightbox-element]").tabIndex,
      -1,
      "it is not tabbable"
    );

    assert.ok(
      query("[data-lightbox-element]").hasAttribute("aria-hidden"),
      "it is hidden from screen readers"
    );

    const container = domFromString(generateLightboxMarkup())[0];

    await setupLightboxes({
      container,
      selector: ".lightbox",
    });

    const lightboxedElement = container.querySelector(".lightbox");
    await click(lightboxedElement);

    await settled();

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-visible"
      ),
      "it is visible"
    );

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-vertical"
      ) ||
        query("[data-lightbox-element]").classList.contains(
          "d-lightbox--is-horizontal"
        ),
      "it has a layout class"
    );

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-zoomed"
      ),
      "it is not zoomed"
    );

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-rotated"
      ),
      "it not rotated"
    );

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-fullscreen"
      ),
      "it is not fullscreen"
    );

    assert.ok(exists("[data-lightbox-content]"), "it has content");

    assert.notOk(
      query("[data-lightbox-element]").hasAttribute("aria-hidden"),
      "it is not hidden from screen readers"
    );

    assert.strictEqual(
      query("[data-lightbox-content]").tabIndex,
      0,
      "the content is tabbable"
    );

    assert.strictEqual(
      query("[data-lightbox-content]").getAttribute("role"),
      "document",
      "the content has a document role"
    );

    assert.ok(
      query("[data-lightbox-content]").getAttribute("aria-labelledby"),
      "the content has an aria-labelledby attribute"
    );

    assert.strictEqual(
      query("[data-lightbox-content]")
        .getAttribute("style")
        .match(/--d-lightbox/g).length,
      8,
      "the content has the corrrect number of css variables"
    );

    assert.ok(
      query("[data-lightbox-focus-trap]"),
      "it has focus traps for keyboard navigation"
    );

    await click("[data-lightbox-close-button]");

    await settled();

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-visible"
      ),
      "it is hidden"
    );

    assert.notOk(exists("[data-lightbox-content]"), "it has no content");

    assert.strictEqual(
      query("[data-lightbox-element]").tabIndex,
      -1,
      "it is not tabbable"
    );

    assert.ok(
      query("[data-lightbox-element]").hasAttribute("aria-hidden"),
      "it is hidden from screen readers"
    );
  });
});
