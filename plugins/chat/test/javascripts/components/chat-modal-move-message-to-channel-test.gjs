import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import MoveMessageToChannel from "discourse/plugins/chat/discourse/components/chat/modal/move-message-to-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | <Chat::Modal::MoveMessageToChannel />",
  function (hooks) {
    setupRenderingTest(hooks);

    test("channel title is escaped in instructions correctly", async function (assert) {
      const self = this;

      this.channel = new ChatFabricators(getOwner(this)).channel({
        title: "<script>someeviltitle</script>",
      });
      this.selectedMessageIds = [this.channel.id];

      await render(
        <template>
          <MoveMessageToChannel
            @inline={{true}}
            @model={{hash
              sourceChannel=self.channel
              selectedMessageIds=self.selectedMessageIds
            }}
          />
        </template>
      );

      assert
        .dom(".chat-modal-move-message-to-channel")
        .includesHtml("&lt;script&gt;someeviltitle&lt;/script&gt;");
    });
  }
);
