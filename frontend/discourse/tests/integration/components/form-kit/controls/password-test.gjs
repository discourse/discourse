import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | Password",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: "" };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Password />
            </form.Field>
          </Form>
        </template>
      );

      assert.form().field("foo").hasValue("");

      await formKit().field("foo").fillIn("bar");

      assert.form().field("foo").hasValue("bar");

      await formKit().submit();

      assert.deepEqual(data.foo, "bar");
    });

    test("toggle visibility", async function (assert) {
      let data = { foo: "test" };

      await render(
        <template>
          <Form @data={{data}} as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Password />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .dom(formKit().field("foo").inputElement)
        .hasAttribute("type", "password");

      await formKit().field("foo").toggle();

      assert
        .dom(formKit().field("foo").inputElement)
        .hasAttribute("type", "text");
    });
  }
);
