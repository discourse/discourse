import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DeleteChannel from "discourse/plugins/chat/discourse/components/chat/modal/delete-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | <Chat::Modal::DeleteChannel />",
  function (hooks) {
    setupRenderingTest(hooks);

    test("channel title is escaped in instructions correctly", async function (assert) {
      const self = this;

      this.channel = new ChatFabricators(getOwner(this)).channel({
        title: `<script>someeviltitle</script>`,
      });

      await render(
        <template>
          <DeleteChannel
            @inline={{true}}
            @model={{hash channel=self.channel}}
          />
        </template>
      );

      assert
        .dom(".chat-modal-delete-channel__instructions")
        .includesHtml("&lt;script&gt;someeviltitle&lt;/script&gt;");
    });
  }
);
