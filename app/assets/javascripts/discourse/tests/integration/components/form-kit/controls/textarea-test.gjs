import { hash } from "@ember/helper";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | Textarea",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: null };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Textarea />
            </form.Field>
          </Form>
        </template>
      );

      assert.deepEqual(data, { foo: null });
      assert.form().field("foo").hasValue("");

      await formKit().field("foo").fillIn("bar");

      assert.form().field("foo").hasValue("bar");

      await formKit().submit();

      assert.deepEqual(data, { foo: "bar" });
    });

    test("when disabled", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" @disabled={{true}} as |field|>
              <field.Textarea />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-textarea").hasAttribute("disabled");
    });

    test("dynamically updates textarea value", async function (assert) {
      let formApi;
      const registerApi = (api) => (formApi = api);

      await render(
        <template>
          <Form
            @data={{hash content="initial value"}}
            @onRegisterApi={{registerApi}}
            as |form|
          >
            <form.Field @name="content" @title="Content" as |field|>
              <field.Textarea />
            </form.Field>
          </Form>
        </template>
      );

      assert.form().field("content").hasValue("initial value");
      assert.dom(".form-kit__control-textarea").hasValue("initial value");

      // Dynamically update the value through the form API
      formApi.set("content", "updated value");
      await settled();

      assert.form().field("content").hasValue("updated value");
      assert.dom(".form-kit__control-textarea").hasValue("updated value");

      // Update to empty string
      formApi.set("content", "");
      await settled();

      assert.form().field("content").hasValue("");
      assert.dom(".form-kit__control-textarea").hasValue("");

      // Update to another value
      formApi.set("content", "final value");
      await settled();

      assert.form().field("content").hasValue("final value");
      assert.dom(".form-kit__control-textarea").hasValue("final value");
    });
  }
);
