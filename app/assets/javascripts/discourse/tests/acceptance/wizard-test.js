import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { click, currentRouteName, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Wizard", function (needs) {
  needs.user();

  test("Wizard starts", async function (assert) {
    await visit("/wizard");
    assert.ok(exists(".wizard-container"));
    assert.strictEqual(currentRouteName(), "wizard.step");
  });

  test("Going back and forth in steps", async function (assert) {
    await visit("/wizard/steps/hello-world");
    assert.ok(exists(".wizard-container__step"));
    assert.ok(
      exists(".wizard-container__step.introduction"),
      "it adds a class for the step id"
    );
    assert.ok(
      !exists(".wizard-container__button.finish"),
      "cannot finish on first step"
    );
    assert.ok(exists(".wizard-progress"));
    assert.ok(exists(".wizard-container__step-title"));
    assert.ok(exists(".wizard-container__step-description"));
    assert.ok(
      !exists(".invalid .field-full-name"),
      "don't show it as invalid until the user does something"
    );
    assert.ok(
      exists(".wizard-container__input .wizard-container__description")
    );
    assert.ok(!exists(".wizard-container__button.back"));
    assert.ok(!exists(".wizard-container__input .field-error-description"));

    // invalid data
    await click(".wizard-container__button.next");
    assert.ok(exists(".invalid .field-full-name"));

    // server validation fail
    await fillIn("input.field-full-name", "Server Fail");
    await click(".wizard-container__button.next");
    assert.ok(exists(".invalid .field-full-name"));
    assert.ok(exists(".wizard-container__input .field-error-description"));

    // server validation ok
    await fillIn("input.field-full-name", "Evil Trout");
    await click(".wizard-container__button.next");
    assert.ok(!exists(".wizard-container__input .field-error-description"));
    assert.ok(!exists(".wizard-container__step-description"));
    assert.ok(
      exists(".wizard-container__button.finish"),
      "shows finish on an intermediate step"
    );

    await click(".wizard-container__button.next");
    assert.ok(exists(".select-kit.field-snack"), "went to the next step");
    assert.ok(
      exists(".wizard-container__preview"),
      "renders the component field"
    );
    assert.ok(
      exists(".wizard-container__button.done"),
      "last step shows a done button"
    );
    assert.ok(exists(".action-link.back"), "shows the back button");
    assert.ok(!exists(".wizard-container__step-title"));
    assert.ok(
      !exists(".wizard-container__button.finish"),
      "cannot finish on last step"
    );

    await click(".action-link.back");
    assert.ok(exists(".wizard-container__step-title"));
    assert.ok(exists(".wizard-container__button.next"));
    assert.ok(!exists(".wizard-prev"));
  });
});
