import { click, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import FormUpload from "discourse/components/form-template-field/upload";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | FormTemplateField | Upload",
  function (hooks) {
    setupRenderingTest(hooks);

    test("removes saved uploads individually", async function (assert) {
      const value =
        "[first.pdf|attachment](https://example.com/first.pdf) (1 KB)\n[second.pdf|attachment](https://example.com/second.pdf) (2 KB)";
      const attributes = { allow_multiple: true };
      const changed = [];
      const onChange = () =>
        changed.push(find("input[name='test-upload']").value);
      await render(
        <template>
          <FormUpload
            @attributes={{attributes}}
            @id="test-upload"
            @onChange={{onChange}}
            @value={{value}}
          />
        </template>
      );
      assert
        .dom(".form-template-field__uploaded-files li")
        .exists({ count: 2 }, "saved uploads have separate controls");
      await click(".form-template-field__remove-upload");
      assert
        .dom("input[name='test-upload']")
        .hasValue(
          value.split("\n")[1],
          "removing one preserves the other upload"
        );
      await click(".form-template-field__remove-upload");
      assert
        .dom("input[name='test-upload']")
        .hasValue("", "all uploads can be removed");
      assert.deepEqual(
        changed,
        [value.split("\n")[1], ""],
        "each removal notifies the composer after updating the input"
      );
    });

    test("sets required attribute when validation is required", async function (assert) {
      const attributes = {};
      const validations = { required: true };

      await render(
        <template>
          <FormUpload
            @attributes={{attributes}}
            @id="test-upload"
            @onChange={{noop}}
            @validations={{validations}}
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
            @attributes={{attributes}}
            @id="test-upload"
            @onChange={{noop}}
            @validations={{validations}}
          />
        </template>
      );

      assert.dom("input[name='test-upload']").doesNotHaveAttribute("required");
    });
  }
);
