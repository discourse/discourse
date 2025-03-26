import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { NO_VALUE_OPTION } from "discourse/components/d-select";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | Select",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: "option-2" };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Select as |select|>
                <select.Option @value="option-1">Option 1</select.Option>
                <select.Option @value="option-2">Option 2</select.Option>
                <select.Option @value="option-3">Option 3</select.Option>
              </field.Select>
            </form.Field>
          </Form>
        </template>
      );

      assert.deepEqual(data, { foo: "option-2" });
      assert.form().field("foo").hasValue("option-2");

      await formKit().field("foo").select("option-3");

      assert.form().field("foo").hasValue("option-3");

      await formKit().submit();

      assert.deepEqual(data, { foo: "option-3" });
    });

    test("@disabled", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" @disabled={{true}} as |field|>
              <field.Select as |select|>
                <select.Option @value="option-1">Option 1</select.Option>
              </field.Select>
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-select").hasAttribute("disabled");
    });

    test("include none", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @validation="required"
              as |field|
            >
              <field.Select />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .form()
        .field("foo")
        .hasValue(NO_VALUE_OPTION, "it has the none when no value is present");

      await render(
        <template>
          <Form @data={{hash foo="1"}} as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @validation="required"
              as |field|
            >
              <field.Select />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .form()
        .field("foo")
        .hasNoValue(
          NO_VALUE_OPTION,
          "doesn't have the none when value is present"
        );

      await render(
        <template>
          <Form @data={{hash foo="1"}} as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Select />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .form()
        .field("foo")
        .hasValue(
          NO_VALUE_OPTION,
          "it has the none when value is present and field is not required"
        );

      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Select />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .form()
        .field("foo")
        .hasValue(
          NO_VALUE_OPTION,
          "it has the none when no value is present and field is not required"
        );

      await render(
        <template>
          <Form @data={{hash foo="1"}} as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Select @includeNone={{false}} />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .form()
        .field("foo")
        .hasNoValue(
          NO_VALUE_OPTION,
          "doesn't have the none for an optional field when value is present and includeNone is false"
        );
    });
  }
);
