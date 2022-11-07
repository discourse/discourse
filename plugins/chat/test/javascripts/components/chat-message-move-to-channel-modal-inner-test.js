import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import fabricators from "../helpers/fabricators";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";

module(
  "Discourse Chat | Component | chat-message-move-to-channel-modal-inner",
  function (hooks) {
    setupRenderingTest(hooks);

    test("channel title is escaped in instructions correctly", async function (assert) {
      this.set(
        "channel",
        fabricators.chatChannel({ title: "<script>someeviltitle</script>" })
      );
      this.set("chat", { publicChannels: [this.channel] });
      this.set("selectedMessageIds", [1]);

      await render(
        hbs`{{chat-message-move-to-channel-modal-inner selectedMessageIds=selectedMessageIds sourceChannel=channel chat=chat}}`
      );

      assert.ok(
        query(".chat-message-move-to-channel-modal-inner").innerHTML.includes(
          "&lt;script&gt;someeviltitle&lt;/script&gt;"
        )
      );
    });
  }
);
