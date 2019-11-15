import { run } from "@ember/runloop";
import startApp from "wizard/test/helpers/start-app";

var wizard;
QUnit.module("Acceptance: wizard", {
  beforeEach() {
    wizard = startApp();
  },

  afterEach() {
    run(wizard, "destroy");
  }
});

test("Wizard starts", async assert => {
  await visit("/");
  assert.ok(exists(".wizard-column-contents"));
  assert.equal(currentPath(), "step");
});

test("Going back and forth in steps", async assert => {
  await visit("/steps/hello-world");
  assert.ok(exists(".wizard-step"));
  assert.ok(
    exists(".wizard-step-hello-world"),
    "it adds a class for the step id"
  );
  assert.ok(!exists(".wizard-btn.finish"), "can’t finish on first step");
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

  // invalid data
  await click(".wizard-btn.next");
  assert.ok(exists(".invalid .field-full-name"));

  // server validation fail
  await fillIn("input.field-full-name", "Server Fail");
  await click(".wizard-btn.next");
  assert.ok(exists(".invalid .field-full-name"));
  assert.ok(exists(".wizard-field .field-error-description"));

  // server validation ok
  await fillIn("input.field-full-name", "Evil Trout");
  await click(".wizard-btn.next");
  assert.ok(!exists(".wizard-field .field-error-description"));
  assert.ok(!exists(".wizard-step-description"));
  assert.ok(
    exists(".wizard-btn.finish"),
    "shows finish on an intermediate step"
  );

  await click(".wizard-btn.next");
  assert.ok(exists(".select-kit.field-snack"), "went to the next step");
  assert.ok(exists(".preview-area"), "renders the component field");
  assert.ok(exists(".wizard-btn.done"), "last step shows a done button");
  assert.ok(exists(".action-link.back"), "shows the back button");
  assert.ok(!exists(".wizard-step-title"));
  assert.ok(!exists(".wizard-btn.finish"), "can’t finish on last step");

  await click(".action-link.back");
  assert.ok(exists(".wizard-step-title"));
  assert.ok(exists(".wizard-btn.next"));
  assert.ok(!exists(".wizard-prev"));
});
