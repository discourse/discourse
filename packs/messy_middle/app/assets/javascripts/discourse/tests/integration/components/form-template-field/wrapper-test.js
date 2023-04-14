import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { exists } from "discourse/tests/helpers/qunit-helpers";

module(
  "Integration | Component | form-template-field | wrapper",
  function (hooks) {
    setupRenderingTest(hooks);

    test("does not render a component when template content has invalid YAML", async function (assert) {
      this.set("content", `- type: checkbox\n  attributes;invalid`);
      await render(
        hbs`<FormTemplateField::Wrapper @content={{this.content}} />`
      );

      assert.notOk(
        exists(".form-template-field"),
        "A form template field should not exist"
      );
      assert.ok(exists(".alert"), "An alert message should exist");
    });

    test("renders a component based on the component type in the template content", async function (assert) {
      const content = `- type: checkbox\n- type: input\n- type: textarea\n- type: dropdown\n- type: upload\n- type: multi-select`;
      const componentTypes = [
        "checkbox",
        "input",
        "textarea",
        "dropdown",
        "upload",
        "multi-select",
      ];
      this.set("content", content);

      await render(
        hbs`<FormTemplateField::Wrapper @content={{this.content}} />`
      );

      componentTypes.forEach((componentType) => {
        assert.ok(
          exists(`.form-template-field[data-field-type='${componentType}']`),
          `${componentType} component exists`
        );
      });
    });
  }
);
