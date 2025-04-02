import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | <Chat::Modal::DeleteChannel />",
  function (hooks) {
    setupRenderingTest(hooks);

    test("channel title is escaped in instructions correctly", async function (assert) {
      this.channel = new ChatFabricators(getOwner(this)).channel({
        title: `<script>someeviltitle</script>`,
      });

      await render(
        hbs`<Chat::Modal::DeleteChannel @inline={{true}} @model={{hash channel=this.channel}} />`
      );

      assert
        .dom(".chat-modal-delete-channel__instructions")
        .includesHtml("&lt;script&gt;someeviltitle&lt;/script&gt;");
    });
  }
);
