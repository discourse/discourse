import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import {
  click,
  currentRouteName,
  currentURL,
  fillIn,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Wizard", function (needs) {
  needs.user();

  test("Wizard starts", async function (assert) {
    await visit("/wizard");
    assert.ok(exists(".wizard-container"));
    assert.notOk(
      exists(".d-header-wrap"),
      "header is not rendered on wizard pages"
    );
    assert.strictEqual(currentRouteName(), "wizard.step");
  });

  test("Going back and forth in steps", async function (assert) {
    await visit("/wizard/steps/hello-world");
    assert.ok(exists(".wizard-container__step"));
    assert.ok(
      exists(".wizard-container__step.hello-world"),
      "it adds a class for the step id"
    );
    assert.ok(
      !exists(".wizard-container__button.finish"),
      "cannot finish on first step"
    );
    assert.ok(exists(".wizard-container__step-progress"));
    assert.ok(exists(".wizard-container__step-title"));
    assert.ok(exists(".wizard-container__step-description"));
    assert.ok(
      !exists(".invalid #full_name"),
      "don't show it as invalid until the user does something"
    );
    assert.ok(!exists(".wizard-container__button.btn-back"));
    assert.ok(!exists(".wizard-container__field .error"));

    // invalid data
    await click(".wizard-container__button.next");
    assert.ok(exists(".invalid #full_name"));

    // server validation fail
    await fillIn("input#full_name", "Server Fail");
    await click(".wizard-container__button.next");
    assert.ok(exists(".invalid #full_name"));
    assert.ok(exists(".wizard-container__field .error"));

    // server validation ok
    await fillIn("input#full_name", "Evil Trout");
    await click(".wizard-container__button.next");
    assert.ok(!exists(".wizard-container__field .error"));
    assert.ok(!exists(".wizard-container__step-description"));
    assert.ok(
      exists(".wizard-container__button.finish"),
      "shows finish on an intermediate step"
    );

    await click(".wizard-container__button.finish");
    assert.strictEqual(
      currentURL(),
      "/latest",
      "it should transition to the homepage"
    );

    await visit("/wizard/steps/styling");

    await click(".wizard-container__button.primary.next");
    assert.ok(
      exists(".wizard-container__text-input#company_name"),
      "went to the next step"
    );
    assert.ok(
      exists(".wizard-container__preview"),
      "renders the component field"
    );
    assert.ok(
      exists(".wizard-container__button.jump-in"),
      "last step shows a jump in button"
    );
    assert.ok(
      exists(".wizard-container__button.btn-back"),
      "shows the back button"
    );
    assert.ok(!exists(".wizard-container__step-title"));
    assert.ok(
      !exists(".wizard-container__button.next"),
      "does not show next button"
    );
    assert.ok(
      !exists(".wizard-container__button.finish"),
      "cannot finish on last step"
    );

    await click(".wizard-container__button.btn-back");
    assert.ok(exists(".wizard-container__step-title"), "shows the step title");
    assert.ok(
      exists(".wizard-container__button.next"),
      "shows the next button"
    );
    await click(".wizard-container__button.next");

    // server validation fail
    await fillIn("input#company_name", "Server Fail");
    await click(".wizard-container__button.jump-in");
    assert.ok(
      exists(".invalid #company_name"),
      "highlights the field with error"
    );
    assert.ok(exists(".wizard-container__field .error"), "shows the error");

    await fillIn("input#company_name", "Foo Bar");
    await click(".wizard-container__button.jump-in");
    assert.strictEqual(
      currentURL(),
      "/latest",
      "it should transition to the homepage"
    );
  });
});
