import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";

module(
  "Discourse Chat | Component | <Chat::Modal::MoveMessageToChannel />",
  function (hooks) {
    setupRenderingTest(hooks);

    test("channel title is escaped in instructions correctly", async function (assert) {
      this.channel = fabricators.channel({
        title: "<script>someeviltitle</script>",
      });
      this.selectedMessageIds = [this.channel.id];

      await render(hbs`
        <Chat::Modal::MoveMessageToChannel
          @inline={{true}}
          @model={{hash sourceChannel=this.channel selectedMessageIds=this.selectedMessageIds}}
        />
      `);

      assert.true(
        query(".chat-modal-move-message-to-channel").innerHTML.includes(
          "&lt;script&gt;someeviltitle&lt;/script&gt;"
        )
      );
    });
  }
);
