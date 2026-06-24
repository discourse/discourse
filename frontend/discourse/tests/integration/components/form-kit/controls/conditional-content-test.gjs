import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | FormKit | Controls | ConditionalContent",
  function (hooks) {
    setupRenderingTest(hooks);

    test("reverts the selection when a controlled change is rejected", async function (assert) {
      const reject = () => {};

      await render(
        <template>
          <Form as |form|>
            <form.ConditionalContent
              @activeName="one"
              @onChange={{reject}}
              as |cc|
            >
              <cc.Conditions as |Condition|>
                <Condition @name="one">One</Condition>
                <Condition @name="two">Two</Condition>
              </cc.Conditions>
            </form.ConditionalContent>
          </Form>
        </template>
      );

      assert.dom("input[value='one']").isChecked();
      assert.dom("input[value='two']").isNotChecked();

      await click("input[value='two']");

      // `onChange` did not update `@activeName`, so the radio must snap back.
      assert.dom("input[value='one']").isChecked();
      assert.dom("input[value='two']").isNotChecked();
    });
  }
);
