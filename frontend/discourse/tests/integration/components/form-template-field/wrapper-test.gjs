import { render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import Wrapper from "discourse/components/form-template-field/wrapper";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module(
  "Integration | Component | FormTemplateField | Wrapper",
  function (hooks) {
    setupRenderingTest(hooks);

    test("loads the selected template when it changes during the initial request", async function (assert) {
      const requests = { firstRequested: false };
      for (const id of [1, 2]) {
        pretender.get(
          `/form-templates/${id}.json`,
          () => {
            requests.firstRequested ||= id === 1;
            return response({
              form_template: {
                id,
                template: `- type: input\n  id: field-${id}\n  attributes:\n    label: Template ${id}`,
              },
            });
          },
          id === 1 ? 100 : 0
        );
      }
      const selections = [];
      const onSelect = (fields, id) => selections.push(id);
      this.set("templateId", 1);
      const renderPromise = render(
        <template>
          <Wrapper @id={{this.templateId}} @onSelectFormTemplate={{onSelect}} />
        </template>
      );

      await waitUntil(() => requests.firstRequested);
      this.set("templateId", 2);
      await renderPromise;

      assert.dom("[name='field-2']").exists();
      assert.deepEqual(selections, [2]);
    });

    test("ignores an older template response after switching templates", async function (assert) {
      const requests = { secondRequested: false };
      for (const id of [1, 2, 3]) {
        pretender.get(
          `/form-templates/${id}.json`,
          () => {
            if (id === 2) {
              requests.secondRequested = true;
            }
            return response({
              form_template: {
                id,
                template: `- type: input\n  id: field-${id}\n  attributes:\n    label: Template ${id}`,
              },
            });
          },
          id === 2 ? 100 : 0
        );
      }
      const selections = [];
      const onSelect = (fields, id) => selections.push(id);
      this.set("templateId", 1);
      await render(
        <template>
          <Wrapper @id={{this.templateId}} @onSelectFormTemplate={{onSelect}} />
        </template>
      );

      this.set("templateId", 2);
      await waitUntil(() => requests.secondRequested);
      this.set("templateId", 3);
      await settled();

      assert.dom("[name='field-3']").exists("the current template is rendered");
      assert.deepEqual(
        selections,
        [1, 3],
        "the stale schema is never selected"
      );
    });

    test("does not render a component when template content has invalid YAML", async function (assert) {
      this.set("content", `- type: checkbox\n  attributes;invalid`);
      await render(
        <template>
          <Wrapper @content={{this.content}} @onChange={{noop}} />
        </template>
      );

      assert
        .dom(".form-template-field")
        .doesNotExist("A form template field should not exist");
      assert.dom(".alert").exists("an alert message should exist");
    });

    test("renders a component based on the component type found in the content YAML", async function (assert) {
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
          <Wrapper @content={{this.content}} @onChange={{noop}} />
        </template>
      );

      componentTypes.forEach((componentType) => {
        assert
          .dom(`.form-template-field[data-field-type='${componentType}']`)
          .exists(`${componentType} component exists`);
      });
    });

    test("renders a component based on the component type found in the content YAML, with initial values", async function (assert) {
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
            @content={{this.content}}
            @initialValues={{this.initialValues}}
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
          <Wrapper @id={{this.formTemplateId}} @onChange={{noop}} />
        </template>
      );

      assert
        .dom(`.form-template-field[data-field-type='checkbox']`)
        .exists("checkbox component renders");
    });
  }
);
