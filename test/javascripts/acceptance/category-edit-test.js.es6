import DiscourseURL from "discourse/lib/url";
import { acceptance } from "helpers/qunit-helpers";

acceptance("Category Edit", {
  loggedIn: true,
  settings: { email_in: true }
});

QUnit.test("Can open the category modal", assert => {
  visit("/c/bug");

  click(".edit-category");
  andThen(() => {
    assert.ok(visible(".d-modal"), "it pops up a modal");
  });

  click("a.close");
  andThen(() => {
    assert.ok(!visible(".d-modal"), "it closes the modal");
  });
});

QUnit.test("Change the category color", assert => {
  visit("/c/bug");

  click(".edit-category");
  fillIn("#edit-text-color", "#ff0000");
  click("#save-category");
  andThen(() => {
    assert.ok(!visible(".d-modal"), "it closes the modal");
    assert.equal(
      DiscourseURL.redirectedTo,
      "/c/bug",
      "it does one of the rare full page redirects"
    );
  });
});

QUnit.test("Change the topic template", assert => {
  visit("/c/bug");

  click(".edit-category");
  click(".edit-category-topic-template");
  fillIn(".d-editor-input", "this is the new topic template");
  click("#save-category");
  andThen(() => {
    assert.ok(!visible(".d-modal"), "it closes the modal");
    assert.equal(
      DiscourseURL.redirectedTo,
      "/c/bug",
      "it does one of the rare full page redirects"
    );
  });
});

QUnit.test("Error Saving", assert => {
  visit("/c/bug");

  click(".edit-category");
  click(".edit-category-settings");
  fillIn(".email-in", "duplicate@example.com");
  click("#save-category");
  andThen(() => {
    assert.ok(visible("#modal-alert"));
    assert.equal(find("#modal-alert").html(), "duplicate email");
  });
});

QUnit.test("Subcategory list settings", assert => {
  const categoryChooser = selectKit(
    ".edit-category-tab-general .category-chooser"
  );

  visit("/c/bug");

  click(".edit-category");
  click(".edit-category-settings");

  andThen(() => {
    assert.ok(
      !visible(".subcategory-list-style-field"),
      "subcategory list style isn't visible by default"
    );
  });

  click(".show-subcategory-list-field input[type=checkbox]");

  andThen(() => {
    assert.ok(
      visible(".subcategory-list-style-field"),
      "subcategory list style is shown if show subcategory list is checked"
    );
  });

  click(".edit-category-general");
  categoryChooser.expand().selectRowByValue(3);
  click(".edit-category-settings");

  andThen(() => {
    assert.ok(
      !visible(".show-subcategory-list-field"),
      "show subcategory list isn't visible for child categories"
    );
    assert.ok(
      !visible(".subcategory-list-style-field"),
      "subcategory list style isn't visible for child categories"
    );
  });
});
