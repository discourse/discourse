import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import fabricators from "../helpers/fabricators";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";

module(
  "Discourse Chat | Component | chat-channel-archive-modal-inner",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("channel", fabricators.chatChannel({}));
    });

    test("channel title is escaped in instructions correctly", async function (assert) {
      this.set("channel.title", `<script>someeviltitle</script>`);

      await render(
        hbs`{{chat-channel-archive-modal-inner chatChannel=channel}}`
      );

      assert.ok(
        query(".chat-channel-archive-modal-instructions").innerHTML.includes(
          "&lt;script&gt;someeviltitle&lt;/script&gt;"
        )
      );
    });
  }
);
