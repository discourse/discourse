import startApp from "wizard/test/helpers/start-app";

var wizard;
QUnit.module("Acceptance: wizard", {
  beforeEach() {
    wizard = startApp();
  },

  afterEach() {
    Ember.run(wizard, "destroy");
  }
});

test("Wizard starts", assert => {
  visit("/");
  andThen(() => {
    assert.ok(exists(".wizard-column-contents"));
    assert.equal(currentPath(), "step");
  });
});

test("Going back and forth in steps", assert => {
  visit("/steps/hello-world");
  andThen(() => {
    assert.ok(exists(".wizard-step"));
    assert.ok(
      exists(".wizard-step-hello-world"),
      "it adds a class for the step id"
    );

    assert.ok(exists(".wizard-progress"));
    assert.ok(exists(".wizard-step-title"));
    assert.ok(exists(".wizard-step-description"));
    assert.ok(
      !exists(".invalid .field-full-name"),
      "don't show it as invalid until the user does something"
    );
    assert.ok(exists(".wizard-field .field-description"));
    assert.ok(!exists(".wizard-btn.back"));
    assert.ok(!exists(".wizard-field .field-error-description"));
  });

  // invalid data
  click(".wizard-btn.next");
  andThen(() => {
    assert.ok(exists(".invalid .field-full-name"));
  });

  // server validation fail
  fillIn("input.field-full-name", "Server Fail");
  click(".wizard-btn.next");
  andThen(() => {
    assert.ok(exists(".invalid .field-full-name"));
    assert.ok(exists(".wizard-field .field-error-description"));
  });

  // server validation ok
  fillIn("input.field-full-name", "Evil Trout");
  click(".wizard-btn.next");
  andThen(() => {
    assert.ok(!exists(".wizard-field .field-error-description"));
    assert.ok(!exists(".wizard-step-title"));
    assert.ok(!exists(".wizard-step-description"));

    assert.ok(exists(".select-kit.field-snack"), "went to the next step");
    assert.ok(exists(".preview-area"), "renders the component field");

    assert.ok(!exists(".wizard-btn.next"));
    assert.ok(exists(".wizard-btn.done"), "last step shows a done button");
    assert.ok(exists(".action-link.back"), "shows the back button");
  });

  click(".action-link.back");
  andThen(() => {
    assert.ok(exists(".wizard-step-title"));
    assert.ok(exists(".wizard-btn.next"));
    assert.ok(!exists(".wizard-prev"));
  });
});
