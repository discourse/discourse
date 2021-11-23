import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";

discourseModule(
  "Integration | Component | select-kit/user-chooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    componentTest("displays usernames", {
      template: hbs`{{user-chooser value=value}}`,

      beforeEach() {
        this.set("value", ["bob", "martin"]);
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().name(), "bob,martin");
      },
    });

    componentTest("can remove a username", {
      template: hbs`{{user-chooser value=value}}`,

      beforeEach() {
        this.set("value", ["bob", "martin"]);
      },

      async test(assert) {
        await this.subject.expand();
        await this.subject.deselectItemByValue("bob");
        assert.strictEqual(this.subject.header().name(), "martin");
      },
    });
  }
);
