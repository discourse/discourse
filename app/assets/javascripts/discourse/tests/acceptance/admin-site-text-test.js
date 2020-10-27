import { exists } from "discourse/tests/helpers/qunit-helpers";
import { fillIn, click, visit, currentURL } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Site Texts", function (needs) {
  needs.user();

  test("search for a key", async (assert) => {
    await visit("/admin/customize/site_texts");

    await fillIn(".site-text-search", "Test");

    assert.equal(currentURL(), "/admin/customize/site_texts?q=Test");
    assert.ok(exists(".site-text"));
    assert.ok(exists(".site-text:not(.overridden)"));
    assert.ok(exists(".site-text.overridden"));

    // Only show overridden
    await click(".search-area .filter-options input");
    assert.equal(
      currentURL(),
      "/admin/customize/site_texts?overridden=true&q=Test"
    );

    assert.ok(!exists(".site-text:not(.overridden)"));
    assert.ok(exists(".site-text.overridden"));
  });

  test("edit and revert a site text by key", async (assert) => {
    await visit("/admin/customize/site_texts/site.test");

    assert.equal(find(".title h3").text(), "site.test");
    assert.ok(!exists(".saved"));
    assert.ok(!exists(".revert-site-text"));

    // Change the value
    await fillIn(".site-text-value", "New Test Value");
    await click(".save-changes");

    assert.ok(exists(".saved"));
    assert.ok(exists(".revert-site-text"));

    // Revert the changes
    await click(".revert-site-text");

    assert.ok(exists(".bootbox.modal"));

    await click(".bootbox.modal .btn-primary");

    assert.ok(!exists(".saved"));
    assert.ok(!exists(".revert-site-text"));
  });
});
