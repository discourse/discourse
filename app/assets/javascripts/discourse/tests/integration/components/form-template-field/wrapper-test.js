import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

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

    test("renders a component based on the component type found in the content YAML", async function (assert) {
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

    test("renders a component based on the component type found in the content YAML when passed ids", async function (assert) {
      pretender.get("/form-templates/1.json", () => {
        return response({
          form_template: {
            id: 1,
            name: "Bug Reports",
            template:
              '- type: checkbox\n  choices:\n    - "Option 1"\n    - "Option 2"\n    - "Option 3"\n  attributes:\n    label: "Enter question here"\n    description: "Enter description here"\n    validations:\n      required: true',
          },
        });
      });

      this.set("formTemplateId", [1]);
      await render(
        hbs`<FormTemplateField::Wrapper @id={{this.formTemplateId}} />`
      );

      assert.ok(
        exists(`.form-template-field[data-field-type='checkbox']`),
        `Checkbox component renders`
      );
    });
  }
);
