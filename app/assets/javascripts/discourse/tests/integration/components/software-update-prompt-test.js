import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  count,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | software-update-prompt", function (hooks) {
  setupRenderingTest(hooks);

  test("software-update-prompt gets correct CSS class after messageBus message", async function (assert) {
    await render(hbs`{{software-update-prompt}}`);

    assert
      .dom("div.software-update-prompt")
      .doesNotExist("it does not have the class to show the prompt");

    await publishToMessageBus("/global/asset-version", "somenewversion");

    assert.strictEqual(
      count("div.software-update-prompt.require-software-refresh"),
      1,
      "it does have the class to show the prompt"
    );
  });
});
