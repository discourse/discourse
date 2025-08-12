import { fn } from "@ember/helper";
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ColorInput from "admin/components/color-input";

module("Integration | Component | ColorInput", function (hooks) {
  setupRenderingTest(hooks);

  const testCases = {
    "black text": ["000", "000000"],
    "white text": ["fff", "ffffff"],
    "2 digit sequence": ["f2f", "f2f2f2"],
    "3 digit sequence": ["DDD", "DDDDDD"],
    "with no sequence": ["0f8", "0f8"],
  };

  async function testHexCode(assert, short, expanded) {
    let result = null;

    const autocompleteHex = (color) => {
      result = color.replace("#", "");
    };

    await render(
      <template><ColorInput @onChangeColor={{fn autocompleteHex}} /></template>
    );

    await fillIn(".hex-input", short);
    assert.strictEqual(result, expanded, "autocompleted hex code");
  }

  Object.entries(testCases).forEach(([name, [short, expanded]]) => {
    test(name, async function (assert) {
      await testHexCode(assert, short, expanded);
    });
  });
});
