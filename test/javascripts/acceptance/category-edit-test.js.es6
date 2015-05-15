import { acceptance } from "helpers/qunit-helpers";

acceptance("Category Edit", { loggedIn: true });

test("Can edit a category", (assert) => {
  visit("/c/bug");

  click('.edit-category');
  andThen(() => {
    assert.ok(visible('#discourse-modal'), 'it pops up a modal');
  });

  click('a.close');
  andThen(() => {
    assert.ok(!visible('#discourse-modal'), 'it closes the modal');
  });
});
