import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Wrapper from "discourse/components/form-template-field/wrapper";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module(
  "Integration | Component | form-template-field | wrapper",
  function (hooks) {
    setupRenderingTest(hooks);

    test("does not render a component when template content has invalid YAML", async function (assert) {
      const self = this;

      this.set("content", `- type: checkbox\n  attributes;invalid`);
      await render(
        <template>
          <Wrapper @content={{self.content}} @onChange={{noop}} />
        </template>
      );

      assert
        .dom(".form-template-field")
        .doesNotExist("A form template field should not exist");
      assert.dom(".alert").exists("an alert message should exist");
    });

    test("renders a component based on the component type found in the content YAML", async function (assert) {
      const self = this;

      const content = `- type: checkbox\n  id: checkbox\n
- type: input\n  id: name
- type: textarea\n  id: notes
- type: dropdown\n  id: dropdown
- type: upload\n  id: upload
- type: multi-select\n  id: multi`;
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
        <template>
          <Wrapper @content={{self.content}} @onChange={{noop}} />
        </template>
      );

      componentTypes.forEach((componentType) => {
        assert
          .dom(`.form-template-field[data-field-type='${componentType}']`)
          .exists(`${componentType} component exists`);
      });
    });

    test("renders a component based on the component type found in the content YAML, with initial values", async function (assert) {
      const self = this;

      const content = `- type: checkbox\n  id: checkbox\n
- type: input\n  id: name
- type: textarea\n  id: notes
- type: dropdown\n  id: dropdown\n  choices:\n    - "Option 1"\n    - "Option 2"\n    - "Option 3"
- type: multi-select\n  id: multi\n  choices:\n    - "Option 1"\n    - "Option 2"\n    - "Option 3"`;
      this.set("content", content);

      this.set("initialValues", {
        checkbox: "on",
        name: "Test Name",
        notes: "Test Notes",
        dropdown: "Option 1",
        multi: ["Option 1"],
      });

      await render(
        <template>
          <Wrapper
            @content={{self.content}}
            @initialValues={{self.initialValues}}
            @onChange={{noop}}
          />
        </template>
      );

      assert.dom("[name='checkbox']").hasValue("on");
      assert.dom("[name='name']").hasValue("Test Name");
      assert.dom("[name='notes']").hasValue("Test Notes");
      assert.dom("[name='dropdown']").hasValue("Option 1");
      assert.dom("[name='multi']").hasValue("Option 1");
    });

    test("renders a component based on the component type found in the content YAML when passed ids", async function (assert) {
      const self = this;

      pretender.get("/form-templates/1.json", () => {
        return response({
          form_template: {
            id: 1,
            name: "Bug Reports",
            template:
              '- type: checkbox\n  id: options\n  choices:\n    - "Option 1"\n    - "Option 2"\n    - "Option 3"\n  attributes:\n    label: "Enter question here"\n    description: "Enter description here"\n    validations:\n      required: true',
          },
        });
      });

      this.set("formTemplateId", [1]);
      await render(
        <template>
          <Wrapper @id={{self.formTemplateId}} @onChange={{noop}} />
        </template>
      );

      assert
        .dom(`.form-template-field[data-field-type='checkbox']`)
        .exists("checkbox component renders");
    });
  }
);
