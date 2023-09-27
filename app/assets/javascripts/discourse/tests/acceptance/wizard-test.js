import {
  click,
  currentRouteName,
  currentURL,
  fillIn,
  visit,
} from "@ember/test-helpers";
import "discourse/routes/wizard";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

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
    assert.ok(exists(".wizard-container__step-title"));
    assert.ok(exists(".wizard-container__step-description"));
    assert.ok(
      !exists(".invalid #full_name"),
      "don't show it as invalid until the user does something"
    );
    assert.ok(!exists(".wizard-container__field .error"));

    // First step: only next button
    assert.ok(!exists(".wizard-canvas"), "First step: no confetti");
    assert.ok(
      !exists(".wizard-container__button.back"),
      "First step: no back button"
    );
    assert.ok(
      exists(".wizard-container__button.next"),
      "First step: next button"
    );
    assert.ok(
      !exists(".wizard-container__button.jump-in"),
      "First step: no jump-in button"
    );
    assert.ok(
      !exists(".wizard-container__button.configure-more"),
      "First step: no configure-more button"
    );
    assert.ok(
      !exists(".wizard-container__button.finish"),
      "First step: no finish button"
    );

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
    assert.ok(
      exists(".wizard-container__step.hello-again"),
      "step: hello-again"
    );
    assert.ok(!exists(".wizard-container__field .error"));
    assert.ok(!exists(".wizard-container__step-description"));

    // Pre-ready: back and next buttons
    assert.ok(!exists(".wizard-canvas"), "Pre-ready step: no confetti");
    assert.ok(
      exists(".wizard-container__button.back"),
      "Pre-ready step: back button"
    );
    assert.ok(
      exists(".wizard-container__button.next"),
      "Pre-ready step: next button"
    );
    assert.ok(
      !exists(".wizard-container__button.jump-in"),
      "Pre-ready step: no jump-in button"
    );
    assert.ok(
      !exists(".wizard-container__button.configure-more"),
      "Pre-ready step: no configure-more button"
    );
    assert.ok(
      !exists(".wizard-container__button.finish"),
      "Pre-ready step: no finish button"
    );

    // ok to skip an optional field
    await click(".wizard-container__button.next");
    assert.ok(exists(".wizard-container__step.ready"), "step: ready");

    // Ready: back, configure-more and jump-in buttons
    assert.ok(exists(".wizard-canvas"), "Ready step: confetti");
    assert.ok(
      exists(".wizard-container__button.back"),
      "Ready step: back button"
    );
    assert.ok(
      !exists(".wizard-container__button.next"),
      "Ready step: no next button"
    );
    assert.ok(
      exists(".wizard-container__button.jump-in"),
      "Ready step: jump-in button"
    );
    assert.ok(
      exists(".wizard-container__button.configure-more"),
      "Ready step: configure-more button"
    );
    assert.ok(
      !exists(".wizard-container__button.finish"),
      "Ready step: no finish button"
    );

    // continue on to optional steps
    await click(".wizard-container__button.configure-more");
    assert.ok(exists(".wizard-container__step.optional"), "step: optional");

    // Post-ready: back, next and finish buttons
    assert.ok(!exists(".wizard-canvas"), "Post-ready step: no confetti");
    assert.ok(
      exists(".wizard-container__button.back"),
      "Post-ready step: back button"
    );
    assert.ok(
      exists(".wizard-container__button.next"),
      "Post-ready step: next button"
    );
    assert.ok(
      !exists(".wizard-container__button.jump-in"),
      "Post-ready step: no jump-in button"
    );
    assert.ok(
      !exists(".wizard-container__button.configure-more"),
      "Post-ready step: no configure-more button"
    );
    assert.ok(
      exists(".wizard-container__button.finish"),
      "Post-ready step: finish button"
    );

    // finish early, does not save/validate
    await click(".wizard-container__button.finish");
    assert.strictEqual(
      currentURL(),
      "/latest",
      "it should transition to the homepage"
    );

    await visit("/wizard/steps/optional");
    assert.ok(exists(".wizard-container__step.optional"), "step: optional");

    // Post-ready: back, next and finish buttons
    assert.ok(!exists(".wizard-canvas"), "Post-ready step: no confetti");
    assert.ok(
      exists(".wizard-container__button.back"),
      "Post-ready step: back button"
    );
    assert.ok(
      exists(".wizard-container__button.next"),
      "Post-ready step: next button"
    );
    assert.ok(
      !exists(".wizard-container__button.jump-in"),
      "Post-ready step: no jump-in button"
    );
    assert.ok(
      !exists(".wizard-container__button.configure-more"),
      "Post-ready step: no configure-more button"
    );
    assert.ok(
      exists(".wizard-container__button.finish"),
      "Post-ready step: finish button"
    );

    await click(".wizard-container__button.primary.next");
    assert.ok(exists(".wizard-container__step.corporate"), "step: corporate");

    // Final step: back and jump-in buttons
    assert.ok(!exists(".wizard-canvas"), "Finish step: no confetti");
    assert.ok(
      exists(".wizard-container__button.back"),
      "Finish step: back button"
    );
    assert.ok(
      !exists(".wizard-container__button.next"),
      "Finish step: no next button"
    );
    assert.ok(
      exists(".wizard-container__button.jump-in"),
      "Finish step: jump-in button"
    );
    assert.ok(
      !exists(".wizard-container__button.configure-more"),
      "Finish step: no configure-more button"
    );
    assert.ok(
      !exists(".wizard-container__button.finish"),
      "Finish step: no finish button"
    );

    assert.ok(
      exists(".wizard-container__text-input#company_name"),
      "went to the next step"
    );
    assert.ok(
      exists(".wizard-container__preview"),
      "renders the component field"
    );
    assert.ok(!exists(".wizard-container__step-title"));

    await click(".wizard-container__button.back");
    assert.ok(exists(".wizard-container__step.optional"), "step: optional");

    // Post-ready: back, next and finish buttons
    assert.ok(!exists(".wizard-canvas"), "Post-ready step: no confetti");
    assert.ok(
      exists(".wizard-container__button.back"),
      "Post-ready step: back button"
    );
    assert.ok(
      exists(".wizard-container__button.next"),
      "Post-ready step: next button"
    );
    assert.ok(
      !exists(".wizard-container__button.jump-in"),
      "Post-ready step: no jump-in button"
    );
    assert.ok(
      !exists(".wizard-container__button.configure-more"),
      "Post-ready step: no configure-more button"
    );
    assert.ok(
      exists(".wizard-container__button.finish"),
      "Post-ready step: finish button"
    );

    assert.ok(exists(".wizard-container__step-title"), "shows the step title");

    await click(".wizard-container__button.next");
    assert.ok(exists(".wizard-container__step.corporate"), "step: optional");

    // Final step: back and jump-in buttons
    assert.ok(!exists(".wizard-canvas"), "Finish step: no confetti");
    assert.ok(
      exists(".wizard-container__button.back"),
      "Finish step: back button"
    );
    assert.ok(
      !exists(".wizard-container__button.next"),
      "Finish step: no next button"
    );
    assert.ok(
      exists(".wizard-container__button.jump-in"),
      "Finish step: jump-in button"
    );
    assert.ok(
      !exists(".wizard-container__button.configure-more"),
      "Finish step: no configure-more button"
    );
    assert.ok(
      !exists(".wizard-container__button.finish"),
      "Finish step: no finish button"
    );

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
