import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";

module(
  "Integration | ui-kit | DPageSubheader independent styles",
  function (hooks) {
    setupRenderingTest(hooks);

    test("Independent030eac semantic heading level retains subheader spacing", async function (assert) {
      await render(
        <template>
          <DPageSubheader @titleLabel="Default" /><DPageSubheader
            @titleHeadingLevel={{3}}
            @titleLabel="Nested"
          />
        </template>
      );
      const baseline = getComputedStyle(find("h2.d-page-subheader__title"));
      const nested = getComputedStyle(find("h3.d-page-subheader__title"));
      assert.strictEqual(
        baseline.marginBottom,
        "0px",
        "subheader stylesheet is loaded, preventing a false green without CSS"
      );
      assert.strictEqual(
        nested.marginBottom,
        baseline.marginBottom,
        "changing document outline preserves title-row spacing"
      );
      assert.strictEqual(
        nested.fontSize,
        baseline.fontSize,
        "subheader typography does not depend on semantic tag"
      );
    });

    test("Independent030eac heading level rejects non-integers and out-of-range values", function (assert) {
      const getter = Object.getOwnPropertyDescriptor(
        DPageSubheader.prototype,
        "titleTag"
      ).get;
      for (const level of [0, 7, -1, 2.5, "3", NaN]) {
        assert.throws(
          () => getter.call({ args: { titleHeadingLevel: level } }),
          /must be 1-6/,
          `rejects invalid level ${level}`
        );
      }
      assert.strictEqual(
        getter.call({ args: {} }),
        getter.call({ args: { titleHeadingLevel: null } }),
        "null and absent both default to h2"
      );
    });
  }
);
