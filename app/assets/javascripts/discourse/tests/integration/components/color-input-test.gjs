import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ColorInput from "admin/components/color-input";

module("Integration | Component | ColorInput", function (hooks) {
  setupRenderingTest(hooks);

  test("autocompletes hex codes", async function (assert) {
    let result;
    const autocompleteHex = (color) => (result = color.replace("#", ""));

    await render(
      <template><ColorInput @onChangeColor={{autocompleteHex}} /></template>
    );

    await fillIn(".hex-input", "000");
    assert.strictEqual(result, "000000", "black text");
    await fillIn(".hex-input", "fff");
    assert.strictEqual(result, "ffffff", "white text");
    await fillIn(".hex-input", "f2f");
    assert.strictEqual(result, "f2f2f2", "2 digit sequence");
    await fillIn(".hex-input", "DDD");
    assert.strictEqual(result, "DDDDDD", "3 digit sequence");
    await fillIn(".hex-input", "0f8");
    assert.strictEqual(result, "0f8", "with no sequence");
  });
});
