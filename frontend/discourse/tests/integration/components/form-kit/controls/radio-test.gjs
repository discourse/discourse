import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | FormKit | Controls | Radio",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @type="radio-group" @name="foo" @title="Foo" as |field|>
              <field.Control as |RadioGroup|>
                <RadioGroup.Radio @value="one">One</RadioGroup.Radio>
              </field.Control>
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-radio-content").hasText("One");
    });

    test("title/description", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @type="radio-group" @name="foo" @title="Foo" as |field|>
              <field.Control as |RadioGroup|>
                <RadioGroup.Radio @value="one" as |radio|>
                  <radio.Title>One title</radio.Title>
                  <radio.Description>One description</radio.Description>
                </RadioGroup.Radio>
              </field.Control>
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-radio-title").hasText("One title");
      assert
        .dom(".form-kit__control-radio-description")
        .hasText("One description");
    });

    test("when disabled", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @type="radio-group"
              @name="foo"
              @title="Foo"
              @disabled={{true}}
              as |field|
            >
              <field.Control as |RadioGroup|>
                <RadioGroup.Radio @value="one" as |radio|>
                  <radio.Title>One title</radio.Title>
                </RadioGroup.Radio>
              </field.Control>
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-radio").hasAttribute("disabled");
    });
  }
);
