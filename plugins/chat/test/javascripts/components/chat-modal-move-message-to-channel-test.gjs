import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | <Chat::Modal::MoveMessageToChannel />",
  function (hooks) {
    setupRenderingTest(hooks);

    test("channel title is escaped in instructions correctly", async function (assert) {
      this.channel = new ChatFabricators(getOwner(this)).channel({
        title: "<script>someeviltitle</script>",
      });
      this.selectedMessageIds = [this.channel.id];

      await render(hbs`
        <Chat::Modal::MoveMessageToChannel
          @inline={{true}}
          @model={{hash sourceChannel=this.channel selectedMessageIds=this.selectedMessageIds}}
        />
      `);

      assert
        .dom(".chat-modal-move-message-to-channel")
        .includesHtml("&lt;script&gt;someeviltitle&lt;/script&gt;");
    });
  }
);
