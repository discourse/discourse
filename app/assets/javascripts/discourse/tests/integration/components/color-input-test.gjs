import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ColorInput from "admin/components/color-input";

module("Integration | Component | ColorInput", function (hooks) {
  setupRenderingTest(hooks);

  test("updates hex codes on blur", async function (assert) {
    let result;
    const expandHex = (color) => (result = color.replace("#", ""));

    await render(<template><ColorInput @onBlur={{expandHex}} /></template>);

    await fillIn(".hex-input", "000");
    await triggerEvent(".hex-input", "blur");
    assert.strictEqual(result, "000000", "with black text");

    await fillIn(".hex-input", "fff");
    await triggerEvent(".hex-input", "blur");
    assert.strictEqual(result, "ffffff", "with white text");

    await fillIn(".hex-input", "f2f");
    await triggerEvent(".hex-input", "blur");
    assert.strictEqual(result, "ff22ff", "with 3 digit hex");

    await fillIn(".hex-input", "052e3d");
    await triggerEvent(".hex-input", "blur");
    assert.strictEqual(result, "052e3d", "with 6 digit hex");
  });

  module("with fallback hex value provided", function (innerHooks) {
    innerHooks.beforeEach(function () {
      this.set("fallbackHexValue", "abcdef");
    });

    test("with empty hex value", async function (assert) {
      this.set("hexValue", "");

      await render(
        <template>
          <ColorInput
            @hexValue={{this.hexValue}}
            @fallbackHexValue={{this.fallbackHexValue}}
          />
        </template>
      );

      assert
        .dom("input.picker")
        .hasValue("#abcdef", "uses fallback color when hexValue is empty")
        .hasAttribute("title", "#abcdef", "sets title to fallback color");
    });

    test("with hex value", async function (assert) {
      this.set("hexValue", "123456");

      await render(
        <template>
          <ColorInput
            @hexValue={{this.hexValue}}
            @fallbackHexValue={{this.fallbackHexValue}}
          />
        </template>
      );

      assert
        .dom(".hex-input")
        .hasValue("123456", "ignores fallback if hexValue is provided");
      assert
        .dom("input.picker")
        .hasValue("#123456", "uses hexValue when provided")
        .hasAttribute("title", "#123456", "uses hexValue when provided");
    });
  });
});
