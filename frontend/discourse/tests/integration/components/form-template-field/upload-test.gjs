import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import FormUpload from "discourse/components/form-template-field/upload";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | form-template-field | upload",
  function (hooks) {
    setupRenderingTest(hooks);

    test("sets required attribute when validation is required", async function (assert) {
      const attributes = {};
      const validations = { required: true };

      await render(
        <template>
          <FormUpload
            @id="test-upload"
            @attributes={{attributes}}
            @validations={{validations}}
            @onChange={{noop}}
          />
        </template>
      );

      assert.dom("input[name='test-upload']").hasAttribute("required");
    });

    test("does not set required attribute when validation is not required", async function (assert) {
      const attributes = {};
      const validations = {};

      await render(
        <template>
          <FormUpload
            @id="test-upload"
            @attributes={{attributes}}
            @validations={{validations}}
            @onChange={{noop}}
          />
        </template>
      );

      assert.dom("input[name='test-upload']").doesNotHaveAttribute("required");
    });
  }
);
