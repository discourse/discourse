import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { module } from "qunit";

module("Discourse Chat | Component | chat-message-text", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("yields", {
    template: hbs`{{#chat-message-text cooked=cooked uploads=uploads}} <div class="yield-me"></div> {{/chat-message-text}}`,

    beforeEach() {
      this.set("cooked", "<p></p>");
    },

    async test(assert) {
      assert.ok(exists(".yield-me"));
    },
  });

  componentTest("shows collapsed", {
    template: hbs`{{chat-message-text cooked=cooked uploads=uploads}}`,

    beforeEach() {
      this.set(
        "cooked",
        '<div class="onebox lazyYT lazyYT-container" data-youtube-id="WaT_rLGuUr8" data-youtube-title="Japanese Katsu Curry (Pork Cutlet)"/>'
      );
    },

    async test(assert) {
      assert.ok(exists(".chat-message-collapser"));
    },
  });

  componentTest("does not collapse a non-image onebox", {
    template: hbs`{{chat-message-text cooked=cooked}}`,

    beforeEach() {
      this.set(
        "cooked",
        '<p><a href="http://cat1.com" class="onebox"></a></p>'
      );
    },

    async test(assert) {
      assert.notOk(exists(".chat-message-collapser"));
    },
  });

  componentTest("shows edits - regular message", {
    template: hbs`{{chat-message-text cooked=cooked edited=true}}`,

    beforeEach() {
      this.set("cooked", "<p></p>");
    },

    async test(assert) {
      assert.ok(exists(".chat-message-edited"));
    },
  });

  componentTest("shows edits - collapsible message", {
    template: hbs`{{chat-message-text cooked=cooked edited=true}}`,

    beforeEach() {
      this.set("cooked", '<div class="onebox lazyYT-container"></div>');
    },

    async test(assert) {
      assert.ok(exists(".chat-message-edited"));
    },
  });
});
