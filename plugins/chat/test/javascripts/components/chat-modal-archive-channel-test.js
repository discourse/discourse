import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";

module(
  "Discourse Chat | Component | <Chat::Modal::ArchiveChannel>",
  function (hooks) {
    setupRenderingTest(hooks);

    test("channel title is escaped in instructions correctly", async function (assert) {
      this.channel = fabricators.channel({
        title: `<script>someeviltitle</script>`,
      });

      await render(
        hbs`<Chat::Modal::ArchiveChannel @inline={{true}} @model={{hash channel=this.channel}} />`
      );

      assert.true(
        query(".chat-modal-archive-channel").innerHTML.includes(
          "&lt;script&gt;someeviltitle&lt;/script&gt;"
        )
      );
    });
  }
);
