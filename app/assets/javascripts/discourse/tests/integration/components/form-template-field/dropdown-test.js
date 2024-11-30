import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module(
  "Integration | Component | form-template-field | dropdown",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("renders a dropdown with choices", async function (assert) {
      const choices = ["Choice 1", "Choice 2", "Choice 3"];
      this.set("choices", choices);

      await render(
        hbs`<FormTemplateField::Dropdown @choices={{this.choices}}/>`
      );
      assert
        .dom(".form-template-field__dropdown")
        .exists("a dropdown component exists");

      const dropdown = queryAll(
        ".form-template-field__dropdown option:not(.form-template-field__dropdown-placeholder)"
      );
      assert.strictEqual(dropdown.length, 3, "it has 3 choices");
      assert.strictEqual(
        dropdown[0].value,
        "Choice 1",
        "it has the correct name for choice 1"
      );
      assert.strictEqual(
        dropdown[1].value,
        "Choice 2",
        "it has the correct name for choice 2"
      );
      assert.strictEqual(
        dropdown[2].value,
        "Choice 3",
        "it has the correct name for choice 3"
      );
    });

    test("renders a dropdown with choices and attributes", async function (assert) {
      const choices = ["Choice 1", "Choice 2", "Choice 3"];
      const attributes = {
        none_label: "Select a choice",
        filterable: true,
      };

      this.set("choices", choices);
      this.set("attributes", attributes);

      await render(
        hbs`<FormTemplateField::Dropdown @choices={{this.choices}} @attributes={{this.attributes}} />`
      );
      assert
        .dom(".form-template-field__dropdown")
        .exists("a dropdown component exists");

      assert
        .dom(".form-template-field__dropdown-placeholder")
        .hasText(attributes.none_label, "None label is correct");
    });

    test("doesn't render a label when attribute is missing", async function (assert) {
      const choices = ["Choice 1", "Choice 2", "Choice 3"];
      this.set("choices", choices);

      await render(
        hbs`<FormTemplateField::Dropdown @choices={{this.choices}} />`
      );

      assert.dom(".form-template-field__label").doesNotExist();
    });
  }
);
