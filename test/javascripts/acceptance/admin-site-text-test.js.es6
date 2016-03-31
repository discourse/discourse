import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - Site Texts", { loggedIn: true });

test("search for a key", () => {
  visit("/admin/customize/site_texts");

  fillIn('.site-text-search', 'Test');
  andThen(() => {
    ok(exists('.site-text'));
    ok(exists(".site-text:not(.overridden)"));
    ok(exists('.site-text.overridden'));
  });


  // Only show overridden
  click('.extra-options input');
  andThen(() => {
    ok(!exists(".site-text:not(.overridden)"));
    ok(exists('.site-text.overridden'));
  });
});


test("edit and revert a site text by key", () => {
  visit("/admin/customize/site_texts/site.test");
  andThen(() => {
    equal(find('.title h3').text(), 'site.test');
    ok(!exists('.save-messages .saved'));
    ok(!exists('.save-messages .saved'));
    ok(!exists('.revert-site-text'));
  });

  // Change the value
  fillIn('.site-text-value', 'New Test Value');
  click(".save-changes");

  andThen(() => {
    ok(exists('.save-messages .saved'));
    ok(exists('.revert-site-text'));
  });

  // Revert the changes
  click('.revert-site-text');
  andThen(() => {
    ok(exists('.bootbox.modal'));
  });
  click('.bootbox.modal .btn-primary');

  andThen(() => {
    ok(!exists('.save-messages .saved'));
    ok(!exists('.revert-site-text'));
  });
});
