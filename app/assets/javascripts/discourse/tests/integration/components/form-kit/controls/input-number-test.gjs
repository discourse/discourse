import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | Input | Number",
  function (hooks) {
    setupRenderingTest(hooks);

    test("@type=number", async function (assert) {
      let data = { foo: "" };
      const mutateData = (x) => (data = x);

      await render(<template>
        <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
          <form.Field @name="foo" @title="Foo" as |field|>
            <field.Input @type="number" />
          </form.Field>
        </Form>
      </template>);

      assert.form().field("foo").hasValue("");

      await formKit().field("foo").fillIn(1);

      assert.form().field("foo").hasValue("1");

      await formKit().submit();

      assert.deepEqual(data.foo, 1);
    });

    test("validation of required", async function (assert) {
      await render(<template>
        <Form as |form|>
          <form.Field
            @name="foo"
            @title="Foo"
            @validation="required"
            as |field|
          >
            <field.Input @type="number" />
          </form.Field>
        </Form>
      </template>);

      await formKit().submit();

      assert.form().hasErrors({ foo: ["Required"] });
      assert.form().field("foo").hasError("Required");

      await fillIn("input", "0");
      await formKit().submit();
      assert.form().field("foo").hasNoErrors();
    });
  }
);
