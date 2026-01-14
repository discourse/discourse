import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import FormInput from "discourse/components/form-template-field/input";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | form-template-field | input",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a text input", async function (assert) {
      await render(<template><FormInput @onChange={{noop}} /></template>);

      assert
        .dom(".form-template-field[data-field-type='input'] input[type='text']")
        .exists("a text input component exists");
    });

    test("renders a text input with attributes", async function (assert) {
      const attributes = {
        label: "My text label",
        placeholder: "Enter text here",
      };

      await render(
        <template>
          <FormInput @attributes={{attributes}} @onChange={{noop}} />
        </template>
      );

      assert
        .dom(".form-template-field[data-field-type='input'] input[type='text']")
        .exists("a text input component exists");

      assert.dom(".form-template-field__label").hasText("My text label");
      assert
        .dom(".form-template-field__input")
        .hasAttribute("placeholder", "Enter text here");
    });

    test("doesn't render a label when attribute is missing", async function (assert) {
      const attributes = {
        placeholder: "Enter text here",
      };

      await render(
        <template>
          <FormInput @attributes={{attributes}} @onChange={{noop}} />
        </template>
      );

      assert.dom(".form-template-field__label").doesNotExist();
    });

    test("renders a description if present", async function (assert) {
      const attributes = {
        description: "Your full name",
      };

      await render(
        <template>
          <FormInput @attributes={{attributes}} @onChange={{noop}} />
        </template>
      );

      assert.dom(".form-template-field__description").hasText("Your full name");
    });

    test("renders a description if present", async function (assert) {
      const attributes = {
        description: "Write your bio here",
      };

      await render(
        <template>
          <FormInput @attributes={{attributes}} @onChange={{noop}} />
        </template>
      );

      assert
        .dom(".form-template-field__description")
        .hasText("Write your bio here");
    });
  }
);
