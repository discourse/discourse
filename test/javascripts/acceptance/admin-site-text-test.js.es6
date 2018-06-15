import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - Site Texts", { loggedIn: true });

QUnit.test("search for a key", assert => {
  visit("/admin/customize/site_texts");

  fillIn(".site-text-search", "Test");
  andThen(() => {
    assert.ok(exists(".site-text"));
    assert.ok(exists(".site-text:not(.overridden)"));
    assert.ok(exists(".site-text.overridden"));
  });

  // Only show overridden
  click(".extra-options input");
  andThen(() => {
    assert.ok(!exists(".site-text:not(.overridden)"));
    assert.ok(exists(".site-text.overridden"));
  });
});

QUnit.test("edit and revert a site text by key", assert => {
  visit("/admin/customize/site_texts/site.test");
  andThen(() => {
    assert.equal(find(".title h3").text(), "site.test");
    assert.ok(!exists(".save-messages .saved"));
    assert.ok(!exists(".save-messages .saved"));
    assert.ok(!exists(".revert-site-text"));
  });

  // Change the value
  fillIn(".site-text-value", "New Test Value");
  click(".save-changes");

  andThen(() => {
    assert.ok(exists(".save-messages .saved"));
    assert.ok(exists(".revert-site-text"));
  });

  // Revert the changes
  click(".revert-site-text");
  andThen(() => {
    assert.ok(exists(".bootbox.modal"));
  });
  click(".bootbox.modal .btn-primary");

  andThen(() => {
    assert.ok(!exists(".save-messages .saved"));
    assert.ok(!exists(".revert-site-text"));
  });
});
