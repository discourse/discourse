import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

module(
  "Integration | Component | FloatKit | d-button-tooltip",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      await render(hbs`
        <DButtonTooltip>
          <:button>
            <DButton />
          </:button>
          <:tooltip>
            <DTooltip />
          </:tooltip>
        </DButtonTooltip>`);

      assert.dom(".btn").exists();
      assert.dom("[data-trigger]").exists();
    });
  }
);
