import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";

module(
  "Integration | Component | form-template-field | input",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a text input", async function (assert) {
      await render(hbs`<FormTemplateField::Input />`);

      assert
        .dom(".form-template-field[data-field-type='input'] input[type='text']")
        .exists("a text input component exists");
    });

    test("renders a text input with attributes", async function (assert) {
      const attributes = {
        label: "My text label",
        placeholder: "Enter text here",
      };
      this.set("attributes", attributes);

      await render(
        hbs`<FormTemplateField::Input @attributes={{this.attributes}} />`
      );

      assert
        .dom(".form-template-field[data-field-type='input'] input[type='text']")
        .exists("a text input component exists");

      assert.dom(".form-template-field__label").hasText("My text label");
      assert.strictEqual(
        query(".form-template-field__input").placeholder,
        "Enter text here"
      );
    });

    test("doesn't render a label when attribute is missing", async function (assert) {
      const attributes = {
        placeholder: "Enter text here",
      };
      this.set("attributes", attributes);

      await render(
        hbs`<FormTemplateField::Input @attributes={{this.attributes}} />`
      );

      assert.dom(".form-template-field__label").doesNotExist();
    });

    test("renders a description if present", async function (assert) {
      const attributes = {
        description: "Your full name",
      };
      this.set("attributes", attributes);

      await render(
        hbs`<FormTemplateField::Input @attributes={{this.attributes}} />`
      );

      assert.dom(".form-template-field__description").hasText("Your full name");
    });
  }
);
