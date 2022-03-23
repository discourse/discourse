import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | replace-emoji", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("width property", {
    template: hbs`{{replace-emoji ":soon:" (hash width=width)}}`,

    async test(assert) {
      assert.equal(
        query(".emoji").getAttribute("width"),
        "20",
        "it defaults to 20"
      );

      this.set("width", 50);

      assert.equal(query(".emoji").getAttribute("width"), "50");
    },
  });

  componentTest("height property", {
    template: hbs`{{replace-emoji ":soon:" (hash height=height)}}`,

    async test(assert) {
      assert.equal(
        query(".emoji").getAttribute("height"),
        "20",
        "it defaults to 20"
      );

      this.set("height", 50);

      assert.equal(query(".emoji").getAttribute("height"), "50");
    },
  });
});
