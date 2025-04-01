import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ArchiveChannel from "discourse/plugins/chat/discourse/components/chat/modal/archive-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | <Chat::Modal::ArchiveChannel>",
  function (hooks) {
    setupRenderingTest(hooks);

    test("channel title is escaped in instructions correctly", async function (assert) {
      const self = this;

      this.channel = new ChatFabricators(getOwner(this)).channel({
        title: `<script>someeviltitle</script>`,
      });

      await render(
        <template>
          <ArchiveChannel
            @inline={{true}}
            @model={{hash channel=self.channel}}
          />
        </template>
      );

      assert
        .dom(".chat-modal-archive-channel")
        .includesHtml("&lt;script&gt;someeviltitle&lt;/script&gt;");
    });
  }
);
