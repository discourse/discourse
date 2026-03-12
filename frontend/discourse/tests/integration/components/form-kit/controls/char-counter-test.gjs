import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | CharCounter",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: null };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @validation="length:0,5"
              as |field|
            >
              <field.Input />
            </form.Field>
          </Form>
        </template>
      );

      assert.form().field("foo").hasCharCounter(0, 5);

      await formKit().field("foo").fillIn("foo");

      assert.form().field("foo").hasCharCounter(3, 5);
    });
  }
);
