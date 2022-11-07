import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module } from "qunit";

module("Discourse Chat | Component | chat-emoji-avatar", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("uses an emoji as avatar", {
    template: hbs`{{chat-emoji-avatar emoji=emoji}}`,

    async beforeEach() {
      this.set("emoji", ":otter:");
    },

    async test(assert) {
      assert.ok(
        exists(
          `.chat-emoji-avatar .chat-emoji-avatar-container .emoji[title=otter]`
        )
      );
    },
  });
});
