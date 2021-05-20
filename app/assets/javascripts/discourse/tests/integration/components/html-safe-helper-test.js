import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | html-safe-helper", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("default", {
    template: hbs`{{html-safe string}}`,

    beforeEach() {
      this.set("string", "<p class='cookies'>biscuits</p>");
    },

    async test(assert) {
      assert.ok(exists("p.cookies"), "it displays the string as html");
    },
  });
});
