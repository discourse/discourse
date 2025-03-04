import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
import softwareUpdatePrompt from "discourse/components/software-update-prompt";

module("Integration | Component | software-update-prompt", function (hooks) {
  setupRenderingTest(hooks);

  test("software-update-prompt gets correct CSS class after messageBus message", async function (assert) {
    await render(<template>{{softwareUpdatePrompt}}</template>);

    assert
      .dom("div.software-update-prompt")
      .doesNotExist("it does not have the class to show the prompt");

    await publishToMessageBus("/global/asset-version", "somenewversion");

    assert
      .dom("div.software-update-prompt")
      .hasClass("require-software-refresh", "has the class to show the prompt");
  });
});
