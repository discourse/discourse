import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FormKit | Layout | Alert", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Alert>Test</form.Alert>
        </Form>
      </template>
    );

    assert.dom(".form-kit__alert-message").hasText("Test");
  });

  test("@icon", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Alert @icon="pencil">Test</form.Alert>
        </Form>
      </template>
    );

    assert.dom(".form-kit__alert .d-icon-pencil").exists();
  });

  test("@type", async function (assert) {
    const types = ["success", "error", "warning", "info"];
    for (let i = 0, length = types.length; i < length; i++) {
      const type = types[i];

      await render(
        <template>
          <Form as |form|>
            <form.Alert @type={{type}}>Test</form.Alert>
          </Form>
        </template>
      );

      assert.dom(`.form-kit__alert.alert.alert-${type}`).exists();
    }
  });
});
