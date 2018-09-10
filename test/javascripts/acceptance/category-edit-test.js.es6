import DiscourseURL from "discourse/lib/url";
import { acceptance } from "helpers/qunit-helpers";

acceptance("Category Edit", {
  loggedIn: true,
  settings: { email_in: true }
});

QUnit.test("Can open the category modal", async assert => {
  await visit("/c/bug");

  await click(".edit-category");
  assert.ok(visible(".d-modal"), "it pops up a modal");

  await click("a.close");
  assert.ok(!visible(".d-modal"), "it closes the modal");
});

QUnit.test("Change the category color", async assert => {
  await visit("/c/bug");

  await click(".edit-category");
  await fillIn("#edit-text-color", "#ff0000");
  await click("#save-category");
  assert.ok(!visible(".d-modal"), "it closes the modal");
  assert.equal(
    DiscourseURL.redirectedTo,
    "/c/bug",
    "it does one of the rare full page redirects"
  );
});

QUnit.test("Change the topic template", async assert => {
  await visit("/c/bug");

  await click(".edit-category");
  await click(".edit-category-topic-template");
  await fillIn(".d-editor-input", "this is the new topic template");
  await click("#save-category");
  assert.ok(!visible(".d-modal"), "it closes the modal");
  assert.equal(
    DiscourseURL.redirectedTo,
    "/c/bug",
    "it does one of the rare full page redirects"
  );
});

QUnit.test("Error Saving", async assert => {
  await visit("/c/bug");

  await click(".edit-category");
  await click(".edit-category-settings");
  await fillIn(".email-in", "duplicate@example.com");
  await click("#save-category");
  assert.ok(visible("#modal-alert"));
  assert.equal(find("#modal-alert").html(), "duplicate email");
});

QUnit.test("Subcategory list settings", async assert => {
  const categoryChooser = selectKit(
    ".edit-category-tab-general .category-chooser"
  );

  await visit("/c/bug");
  await click(".edit-category");
  await click(".edit-category-settings a");

  assert.ok(
    !visible(".subcategory-list-style-field"),
    "subcategory list style isn't visible by default"
  );

  await click(".show-subcategory-list-field input[type=checkbox]");

  assert.ok(
    visible(".subcategory-list-style-field"),
    "subcategory list style is shown if show subcategory list is checked"
  );

  await click(".edit-category-general");
  await categoryChooser.expand();
  await categoryChooser.selectRowByValue(3);

  await click(".edit-category-settings a");

  assert.ok(
    !visible(".show-subcategory-list-field"),
    "show subcategory list isn't visible for child categories"
  );
  assert.ok(
    !visible(".subcategory-list-style-field"),
    "subcategory list style isn't visible for child categories"
  );
});
