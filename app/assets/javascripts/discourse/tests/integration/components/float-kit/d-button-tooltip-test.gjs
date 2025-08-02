import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DButton from "discourse/components/d-button";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DButtonTooltip from "float-kit/components/d-button-tooltip";
import DTooltip from "float-kit/components/d-tooltip";

module(
  "Integration | Component | FloatKit | d-button-tooltip",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      await render(
        <template>
          <DButtonTooltip>
            <:button>
              <DButton />
            </:button>
            <:tooltip>
              <DTooltip />
            </:tooltip>
          </DButtonTooltip>
        </template>
      );

      assert.dom(".btn").exists();
      assert.dom("[data-trigger]").exists();
    });
  }
);
