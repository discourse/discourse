import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import {
  count,
  exists,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | software-update-prompt", function (hooks) {
  setupRenderingTest(hooks);

  test("software-update-prompt gets correct CSS class after messageBus message", async function (assert) {
    await render(hbs`{{software-update-prompt}}`);

    assert.ok(
      !exists("div.software-update-prompt"),
      "it does not have the class to show the prompt"
    );

    await publishToMessageBus("/global/asset-version", "somenewversion");

    assert.strictEqual(
      count("div.software-update-prompt.require-software-refresh"),
      1,
      "it does have the class to show the prompt"
    );
  });
});
