import { fn } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FormKit | Layout | Button", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    const done = assert.async();
    const somethingAction = (value) => {
      assert.deepEqual(value, 1);
      done();
    };

    await render(
      <template>
        <Form as |form|>
          <form.Button class="something" @action={{fn somethingAction 1}} />
        </Form>
      </template>
    );

    await click(".something");
  });
});
