import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FormKit | Layout | Row", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Row as |row|>
            <row.Col>Test</row.Col>
          </form.Row>
        </Form>
      </template>
    );

    assert.dom(".form-kit__row .form-kit__col").hasText("Test");
  });

  test("@size", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Row as |row|>
            <row.Col @size={{6}}>Test</row.Col>
          </form.Row>
        </Form>
      </template>
    );

    assert.dom(".form-kit__row .form-kit__col.--col-6").hasText("Test");
  });
});
