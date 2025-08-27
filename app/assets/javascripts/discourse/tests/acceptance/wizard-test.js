import {
  click,
  currentRouteName,
  currentURL,
  fillIn,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Wizard", function (needs) {
  needs.user();

  test("Wizard starts", async function (assert) {
    await visit("/wizard");
    assert.dom(".wizard-container").exists();
    assert
      .dom(".d-header-wrap")
      .doesNotExist("header is not rendered on wizard pages");
    assert.strictEqual(currentRouteName(), "wizard.step");
  });

  test("Going back and forth in steps", async function (assert) {
    await visit("/wizard/steps/hello-world");
    assert.dom(".wizard-container__step").exists();
    assert
      .dom(".wizard-container__step.hello-world")
      .exists("it adds a class for the step id");
    assert.dom(".wizard-container__step-title").exists();
    assert.dom(".wizard-container__step-description").exists();
    assert
      .dom(".invalid #full_name")
      .doesNotExist("don't show it as invalid until the user does something");
    assert.dom(".wizard-container__field .error").doesNotExist();

    // First step: only next button
    assert.dom(".wizard-canvas").doesNotExist("First step: no confetti");
    assert
      .dom(".wizard-container__button.back")
      .doesNotExist("First step: no back button");
    assert
      .dom(".wizard-container__button.next")
      .exists("First step: next button");
    assert
      .dom(".wizard-container__button.jump-in")
      .doesNotExist("First step: no jump-in button");
    assert
      .dom(".wizard-container__button.finish")
      .doesNotExist("First step: no finish button");

    // invalid data
    await click(".wizard-container__button.next");
    assert.dom(".invalid #full_name").exists();

    // server validation fail
    await fillIn("input#full_name", "Server Fail");
    await click(".wizard-container__button.next");
    assert.dom(".invalid #full_name").exists();
    assert.dom(".wizard-container__field .error").exists();

    // server validation ok
    await fillIn("input#full_name", "Evil Trout");
    await click(".wizard-container__button.next");
    assert
      .dom(".wizard-container__step.hello-again")
      .exists("step: hello-again");
    assert.dom(".wizard-container__field .error").doesNotExist();
    assert.dom(".wizard-container__step-description").doesNotExist();

    // Pre-ready: back and next buttons
    assert.dom(".wizard-canvas").doesNotExist("Pre-ready step: no confetti");
    assert
      .dom(".wizard-container__button.back")
      .exists("Pre-ready step: back button");
    assert
      .dom(".wizard-container__button.next")
      .exists("Pre-ready step: next button");
    assert
      .dom(".wizard-container__button.jump-in")
      .doesNotExist("Pre-ready step: no jump-in button");
    assert
      .dom(".wizard-container__button.finish")
      .doesNotExist("Pre-ready step: no finish button");

    // ok to skip an optional field
    await click(".wizard-container__button.next");
    assert.dom(".wizard-container__step.ready").exists("step: ready");

    // Ready: back, configure-more and jump-in buttons
    assert.dom(".wizard-canvas").exists("Ready step: confetti");
    assert
      .dom(".wizard-container__button.back")
      .exists("Ready step: back button");
    assert
      .dom(".wizard-container__button.next")
      .doesNotExist("Ready step: no next button");
    assert
      .dom(".wizard-container__button.jump-in")
      .exists("Ready step: jump-in button");
    assert
      .dom(".wizard-container__button.finish")
      .doesNotExist("Ready step: no finish button");

    // Final step: back and jump-in buttons
    assert.dom(".wizard-canvas").exists("Finish step: no confetti");
    assert
      .dom(".wizard-container__button.back")
      .exists("Finish step: back button");
    assert
      .dom(".wizard-container__button.next")
      .doesNotExist("Finish step: no next button");
    assert
      .dom(".wizard-container__button.jump-in")
      .exists("Finish step: jump-in button");

    // Final step: back and jump-in buttons
    assert.dom(".wizard-canvas").exists("Finish step: no confetti");
    assert
      .dom(".wizard-container__button.back")
      .exists("Finish step: back button");
    assert
      .dom(".wizard-container__button.next")
      .doesNotExist("Finish step: no next button");
    assert
      .dom(".wizard-container__button.jump-in")
      .exists("Finish step: jump-in button");

    await click(".wizard-container__button.jump-in");

    assert.strictEqual(
      currentURL(),
      "/latest",
      "it should transition to the homepage"
    );
  });
});
