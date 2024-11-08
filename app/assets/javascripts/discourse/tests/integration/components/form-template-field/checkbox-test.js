import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | form-template-field | checkbox",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a checkbox input", async function (assert) {
      await render(hbs`<FormTemplateField::Checkbox />`);

      assert
        .dom(
          ".form-template-field[data-field-type='checkbox'] input[type='checkbox']"
        )
        .exists("a checkbox component exists");
    });

    test("renders a checkbox with a label", async function (assert) {
      const attributes = {
        label: "Click this box",
      };
      this.set("attributes", attributes);

      await render(
        hbs`<FormTemplateField::Checkbox @attributes={{this.attributes}} />`
      );

      assert
        .dom(
          ".form-template-field[data-field-type='checkbox'] input[type='checkbox']"
        )
        .exists("a checkbox component exists");

      assert.dom(".form-template-field__label").hasText("Click this box");
    });
  }
);
