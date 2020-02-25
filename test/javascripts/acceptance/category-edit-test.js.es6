import selectKit from "helpers/select-kit-helper";
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

  await click("button.modal-close");
  assert.ok(!visible(".d-modal"), "it closes the modal");
});

QUnit.test("Editing the category", async assert => {
  await visit("/c/bug");

  await click(".edit-category");
  await fillIn("#edit-text-color", "#ff0000");

  await click(".edit-category-topic-template");
  await fillIn(".d-editor-input", "this is the new topic template");

  await click(".edit-category-settings");
  const searchPriorityChooser = selectKit("#category-search-priority");
  await searchPriorityChooser.expand();
  await searchPriorityChooser.selectRowByValue(1);

  await click("#save-category");

  assert.ok(!visible(".d-modal"), "it closes the modal");
  assert.equal(
    DiscourseURL.redirectedTo,
    "/c/bug/1",
    "it does one of the rare full page redirects"
  );
});

QUnit.skip("Edit the description without loosing progress", async assert => {
  let win = { focus: function() {} };
  let windowOpen = sandbox.stub(window, "open").returns(win);
  sandbox.stub(win, "focus");

  await visit("/c/bug");

  await click(".edit-category");
  await click(".edit-category-description");
  assert.ok(
    windowOpen.calledWith("/t/category-definition-for-bug/2", "_blank"),
    "opens the category topic in a new tab"
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
