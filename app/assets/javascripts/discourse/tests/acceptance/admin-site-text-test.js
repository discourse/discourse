import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";

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
    assert.ok(exists(".site-text"));
    assert.ok(exists(".site-text:not(.overridden)"));
    assert.ok(exists(".site-text.overridden"));

    // Only show overridden
    await click(".search-area .filter-options input");
    assert.strictEqual(
      currentURL(),
      "/admin/customize/site_texts?overridden=true&q=Test"
    );

    assert.ok(!exists(".site-text:not(.overridden)"));
    assert.ok(exists(".site-text.overridden"));
  });

  test("edit and revert a site text by key", async function (assert) {
    await visit("/admin/customize/site_texts/site.test?locale=en");

    assert.strictEqual(query(".title h3").innerText, "site.test");
    assert.ok(!exists(".saved"));
    assert.ok(!exists(".revert-site-text"));

    // Change the value
    await fillIn(".site-text-value", "New Test Value");
    await click(".save-changes");

    assert.ok(exists(".saved"));
    assert.ok(exists(".revert-site-text"));

    // Revert the changes
    await click(".revert-site-text");

    assert.ok(exists("#dialog-holder .dialog-content"));

    await click("#dialog-holder .btn-primary");

    assert.ok(!exists(".saved"));
    assert.ok(!exists(".revert-site-text"));
  });
});
