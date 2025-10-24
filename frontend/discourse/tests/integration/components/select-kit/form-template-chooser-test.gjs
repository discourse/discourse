import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import FormTemplateChooser from "select-kit/components/form-template-chooser";

module(
  "Integration | Component | select-kit/form-template-chooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
      pretender.get("/form-templates.json", () => {
        return response({
          form_templates: [
            { id: 1, name: "template 1", template: "test: true" },
            { id: 2, name: "template 2", template: "test: false" },
          ],
        });
      });
    });

    test("displays form templates", async function (assert) {
      await render(<template><FormTemplateChooser /></template>);

      await this.subject.expand();

      assert.strictEqual(this.subject.rowByIndex(0).value(), "1");
      assert.strictEqual(this.subject.rowByIndex(1).value(), "2");
    });

    test("displays selected value", async function (assert) {
      const self = this;

      this.set("value", [1]);

      await render(
        <template><FormTemplateChooser @value={{self.value}} /></template>
      );

      assert.strictEqual(this.subject.header().name(), "template 1");
    });

    test("when no templates are available, the select is disabled", async function (assert) {
      pretender.get("/form-templates.json", () => {
        return response({ form_templates: [] });
      });

      await render(<template><FormTemplateChooser /></template>);
      assert.true(this.subject.isDisabled());
    });
  }
);
