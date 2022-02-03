import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { click, triggerKeyEvent } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | flat-button", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("press Enter", {
    template: hbs`{{flat-button action=action}}`,

    beforeEach() {
      this.set("foo", null);
      this.set("action", () => {
        this.set("foo", "bar");
      });
    },

    async test(assert) {
      await triggerKeyEvent(".btn-flat", "keydown", 32);

      assert.strictEqual(this.foo, null);

      await triggerKeyEvent(".btn-flat", "keydown", 13);

      assert.strictEqual(this.foo, "bar");
    },
  });
  componentTest("click", {
    template: hbs`{{flat-button action=action}}`,

    beforeEach() {
      this.set("foo", null);
      this.set("action", () => {
        this.set("foo", "bar");
      });
    },

    async test(assert) {
      await click(".btn-flat");

      assert.strictEqual(this.foo, "bar");
    },
  });
});
