import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Site Texts", function (needs) {
  needs.user();
  needs.settings({
    available_locales: JSON.stringify([{ name: "English", value: "en" }]),
    default_locale: "en",
  });

  test("search for a key", async function (assert) {
    await visit("/admin/customize/site_texts");

    await fillIn(".site-text-search", "Test");

    assert.strictEqual(currentURL(), "/admin/customize/site_texts?q=Test");
    assert.dom(".site-text").exists();
    assert.dom(".site-text:not(.overridden)").exists();
    assert.dom(".site-text.overridden").exists();

    // Only show overridden
    await click(".search-area .filter-options #toggle-overridden");
    assert.strictEqual(
      currentURL(),
      "/admin/customize/site_texts?overridden=true&q=Test"
    );

    assert.dom(".site-text:not(.overridden)").doesNotExist();
    assert.dom(".site-text.overridden").exists();
    await click(".search-area .filter-options #toggle-overridden");

    // Only show outdated
    await click(".search-area .filter-options #toggle-outdated");
    assert.strictEqual(
      currentURL(),
      "/admin/customize/site_texts?outdated=true&q=Test"
    );
  });

  test("edit and revert a site text by key", async function (assert) {
    await visit("/admin/customize/site_texts/site.test?locale=en");

    assert.dom(".title h3").hasText("site.test");
    assert.dom(".saved").doesNotExist();
    assert.dom(".revert-site-text").doesNotExist();

    // Change the value
    await fillIn(".site-text-value", "New Test Value");
    await click(".save-changes");

    assert.dom(".saved").exists();
    assert.dom(".revert-site-text").exists();

    // Revert the changes
    await click(".revert-site-text");

    assert.dom("#dialog-holder .dialog-content").exists();

    await click("#dialog-holder .btn-primary");

    assert.dom(".saved").doesNotExist();
    assert.dom(".revert-site-text").doesNotExist();
  });
});
