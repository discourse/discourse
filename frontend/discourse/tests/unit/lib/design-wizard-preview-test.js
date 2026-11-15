import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { swatchStyle } from "discourse/lib/design-wizard-preview";

function leadColor(palette) {
  return `${swatchStyle(palette)}`.match(/linear-gradient\(135deg, (#\w+)/)[1];
}

module("Unit | Lib | design-wizard-preview", function (hooks) {
  setupTest(hooks);

  test("swatchStyle leads with the accent", function (assert) {
    assert.strictEqual(
      leadColor({
        colors: {
          secondary: "ffffff",
          tertiary: "0088cc",
          header_background: "fff",
        },
      }),
      "#0088cc",
      "a header matching the background doesn't count as a color"
    );
    assert.strictEqual(
      leadColor({
        colors: {
          secondary: "2d303e",
          tertiary: "bd93f9",
          header_background: "373A47",
        },
      }),
      "#bd93f9",
      "a header only slightly off the background doesn't count either"
    );
    assert.strictEqual(
      leadColor({ colors: { secondary: "ffffff", tertiary: "0088cc" } }),
      "#0088cc",
      "a palette without a header color uses the accent"
    );
  });

  test("swatchStyle leads with a header distinct from the background", function (assert) {
    assert.strictEqual(
      leadColor({
        colors: {
          secondary: "3a2a37",
          tertiary: "fdd459",
          header_background: "a97189",
        },
      }),
      "#a97189"
    );
  });
});
