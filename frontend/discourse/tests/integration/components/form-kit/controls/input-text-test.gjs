import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | Input | Text",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: "" };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @type="input" @name="foo" @title="Foo" as |field|>
              <field.Control />
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

    test("when disabled", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @type="input"
              @name="foo"
              @title="Foo"
              @disabled={{true}}
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-input").hasAttribute("disabled");
    });

    test("when emptied", async function (assert) {
      let data = { foo: "xxx" };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{mutateData}} as |form|>
            <form.Field @type="input" @name="foo" @title="Foo" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      await formKit().field("foo").fillIn("");
      await formKit().submit();

      assert.deepEqual(data.foo, null, "it nullifies the value");
    });

    test("@before and @after", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @type="input" @name="foo" @title="Foo" as |field|>
              <field.Control @before="https://" @after=".com" />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__before-input").hasText("https://");
      assert.dom(".form-kit__after-input").hasText(".com");
      assert.dom(".form-kit__control-input").hasClass("has-prefix");
      assert.dom(".form-kit__control-input").hasClass("has-suffix");
    });
  }
);
