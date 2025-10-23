import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MultiSelect from "discourse/components/form-template-field/multi-select";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module(
  "Integration | Component | form-template-field | multi-select",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("renders a multi-select dropdown with choices", async function (assert) {
      const self = this;

      const choices = ["Choice 1", "Choice 2", "Choice 3"];

      this.set("choices", choices);

      await render(
        <template>
          <MultiSelect @choices={{self.choices}} @onChange={{noop}} />
        </template>
      );
      assert
        .dom(".form-template-field__multi-select")
        .exists("a multiselect component exists");

      const dropdown = queryAll(
        ".form-template-field__multi-select option:not(.form-template-field__multi-select-placeholder)"
      );
      assert.strictEqual(dropdown.length, 3, "it has 3 choices");
      assert
        .dom(dropdown[0])
        .hasValue("Choice 1", "has the correct name for choice 1");
      assert
        .dom(dropdown[1])
        .hasValue("Choice 2", "has the correct name for choice 2");
      assert
        .dom(dropdown[2])
        .hasValue("Choice 3", "has the correct name for choice 3");
    });

    test("renders a multi-select with choices and attributes", async function (assert) {
      const self = this;

      const choices = ["Choice 1", "Choice 2", "Choice 3"];
      const attributes = {
        none_label: "Select a choice",
        filterable: true,
      };

      this.set("choices", choices);
      this.set("attributes", attributes);

      await render(
        <template>
          <MultiSelect
            @choices={{self.choices}}
            @attributes={{self.attributes}}
            @onChange={{noop}}
          />
        </template>
      );
      assert
        .dom(".form-template-field__multi-select")
        .exists("a multiselect dropdown component exists");

      assert
        .dom(".form-template-field__multi-select-placeholder")
        .hasText(attributes.none_label, "None label is correct");
    });

    test("doesn't render a label when attribute is missing", async function (assert) {
      const self = this;

      const choices = ["Choice 1", "Choice 2", "Choice 3"];
      this.set("choices", choices);

      await render(
        <template>
          <MultiSelect @choices={{self.choices}} @onChange={{noop}} />
        </template>
      );

      assert.dom(".form-template-field__label").doesNotExist();
    });
  }
);
