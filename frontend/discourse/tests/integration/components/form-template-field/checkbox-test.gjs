import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Checkbox from "discourse/components/form-template-field/checkbox";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | form-template-field | checkbox",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a checkbox input", async function (assert) {
      await render(<template><Checkbox @onChange={{noop}} /></template>);

      assert
        .dom(
          ".form-template-field[data-field-type='checkbox'] input[type='checkbox']"
        )
        .exists("a checkbox component exists");
    });

    test("renders a checkbox with a label", async function (assert) {
      const attributes = {
        label: "Click this box",
      };

      await render(
        <template>
          <Checkbox @attributes={{attributes}} @onChange={{noop}} />
        </template>
      );

      assert
        .dom(
          ".form-template-field[data-field-type='checkbox'] input[type='checkbox']"
        )
        .exists("a checkbox component exists");

      assert.dom(".form-template-field__label").hasText("Click this box");
    });
  }
);
