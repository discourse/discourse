import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module } from "qunit";

module(
  "Discourse Chat | Component | chat-composer-inline-buttons",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("buttons", {
      template: hbs`{{chat-composer-inline-buttons buttons=buttons}}`,

      async beforeEach() {
        this.set("buttons", [{ id: "foo", icon: "times", action: () => {} }]);
      },

      async test(assert) {
        assert.ok(exists(".chat-composer-inline-button.foo"));
        assert.ok(exists(".chat-composer-inline-button.foo .d-icon-times"));
      },
    });
  }
);
