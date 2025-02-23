import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | form-template-field | textarea",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a textarea input", async function (assert) {
      await render(hbs`<FormTemplateField::Textarea />`);

      assert
        .dom(".form-template-field__textarea")
        .exists("a textarea input component exists");
    });

    test("renders a text input with attributes", async function (assert) {
      const attributes = {
        label: "My text label",
        placeholder: "Enter text here",
      };
      this.set("attributes", attributes);

      await render(
        hbs`<FormTemplateField::Textarea @attributes={{this.attributes}} />`
      );

      assert
        .dom(".form-template-field__textarea")
        .exists("a textarea input component exists");

      assert.dom(".form-template-field__label").hasText("My text label");
      assert
        .dom(".form-template-field__textarea")
        .hasAttribute("placeholder", "Enter text here");
    });

    test("doesn't render a label when attribute is missing", async function (assert) {
      const attributes = {
        placeholder: "Enter text here",
      };
      this.set("attributes", attributes);

      await render(
        hbs`<FormTemplateField::Textarea @attributes={{this.attributes}} />`
      );

      assert.dom(".form-template-field__label").doesNotExist();
    });

    test("renders a description if present", async function (assert) {
      const attributes = {
        description: "Write your bio here",
      };
      this.set("attributes", attributes);

      await render(
        hbs`<FormTemplateField::Input @attributes={{this.attributes}} />`
      );

      assert
        .dom(".form-template-field__description")
        .hasText("Write your bio here");
    });
  }
);
