import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | FormKit | Layout | Actions",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Actions class="something">Test</form.Actions>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__section.form-kit__actions.something")
        .hasText("Test");
    });
  }
);
