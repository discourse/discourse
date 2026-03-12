import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | InputGroup",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = {};
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.InputGroup as |inputGroup|>
              <inputGroup.Field @title="Foo" @name="foo" as |field|>
                <field.Input />
              </inputGroup.Field>
              <inputGroup.Field @title="Bar" @name="bar" as |field|>
                <field.Input />
              </inputGroup.Field>
            </form.InputGroup>
          </Form>
        </template>
      );

      assert.form().field("foo").hasValue("");
      assert.form().field("bar").hasValue("");
      assert.deepEqual(data, {});

      await formKit().field("foo").fillIn("foobar");
      await formKit().field("bar").fillIn("barbaz");

      assert.form().field("foo").hasValue("foobar");
      assert.form().field("bar").hasValue("barbaz");

      await formKit().submit();

      assert.deepEqual(data, { foo: "foobar", bar: "barbaz" });
    });
  }
);
