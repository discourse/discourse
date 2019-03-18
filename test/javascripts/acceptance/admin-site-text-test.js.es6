import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - Site Texts", { loggedIn: true });

QUnit.test("search for a key", async assert => {
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

QUnit.test("edit and revert a site text by key", async assert => {
  await visit("/admin/customize/site_texts/site.test");

  assert.equal(find(".title h3").text(), "site.test");
  assert.ok(!exists(".save-messages .saved"));
  assert.ok(!exists(".save-messages .saved"));
  assert.ok(!exists(".revert-site-text"));

  // Change the value
  await fillIn(".site-text-value", "New Test Value");
  await click(".save-changes");

  assert.ok(exists(".save-messages .saved"));
  assert.ok(exists(".revert-site-text"));

  // Revert the changes
  await click(".revert-site-text");

  assert.ok(exists(".bootbox.modal"));

  await click(".bootbox.modal .btn-primary");

  assert.ok(!exists(".save-messages .saved"));
  assert.ok(!exists(".revert-site-text"));
});
