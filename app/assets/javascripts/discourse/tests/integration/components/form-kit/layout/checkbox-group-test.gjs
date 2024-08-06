import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | FormKit | Layout | CheckboxGroup",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      await render(<template>
        <Form as |form|>
          <form.CheckboxGroup as |checkboxGroup|>
            <checkboxGroup.Field @name="foo" @title="Foo" as |field|>
              <field.Checkbox />
            </checkboxGroup.Field>
            <checkboxGroup.Field @name="bar" @title="Bar" as |field|>
              <field.Checkbox>A description</field.Checkbox>
            </checkboxGroup.Field>
          </form.CheckboxGroup>
        </Form>
      </template>);

      assert.form().field("foo").hasTitle("Foo");
      assert.form().field("bar").hasTitle("Bar");
      assert.form().field("bar").hasDescription("A description");
    });
  }
);
