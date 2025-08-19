import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | RadioGroup",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: "one" };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.RadioGroup as |RadioGroup|>
                <RadioGroup.Radio @value="one">One</RadioGroup.Radio>
                <RadioGroup.Radio @value="two">Two</RadioGroup.Radio>
                <RadioGroup.Radio @value="three">Three</RadioGroup.Radio>
              </field.RadioGroup>
            </form.Field>
          </Form>
        </template>
      );

      assert.form().field("foo").hasValue("one");

      await formKit().field("foo").select("two");

      assert.form().field("foo").hasValue("two");

      await formKit().submit();

      assert.deepEqual(data.foo, "two");
    });
  }
);
