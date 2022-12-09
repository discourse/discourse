import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { click } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { exists, query, visible } from "discourse/tests/helpers/qunit-helpers";
import { module } from "qunit";
import { htmlSafe } from "@ember/template";

module("Discourse Chat | Component | collapser", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("renders header", {
    template: hbs`{{collapser header=header}}`,

    beforeEach() {
      this.set("header", htmlSafe("<div class='cat'>tomtom</div>"));
    },

    async test(assert) {
      const element = query(".cat");

      assert.ok(exists(element));
    },
  });

  componentTest("collapses and expands yielded body", {
    template: hbs`{{#collapser}}<div class='cat'>body text</div>{{/collapser}}`,

    test: async function (assert) {
      const openButton = ".chat-message-collapser-closed";
      const closeButton = ".chat-message-collapser-opened";
      const body = ".cat";

      assert.ok(visible(body));
      await click(closeButton);

      assert.notOk(visible(body));

      await click(openButton);

      assert.ok(visible(body));
    },
  });
});
