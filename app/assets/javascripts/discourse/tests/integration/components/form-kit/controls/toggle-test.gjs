import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | Toggle",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: null };

      await render(<template>
        <Form @mutable={{true}} @data={{data}} as |form|>
          <form.Field @name="foo" @title="Foo" as |field|>
            <field.Toggle />
          </form.Field>
        </Form>
      </template>);

      assert.deepEqual(data, { foo: null });
      assert.form().field("foo").hasValue(false);

      await formKit().field("foo").toggle();

      assert.deepEqual(data, { foo: true });
      assert.form().field("foo").hasValue(true);
    });
  }
);
