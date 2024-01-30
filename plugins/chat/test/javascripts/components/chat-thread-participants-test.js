import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | <ChatThreadParticipants />",
  function (hooks) {
    setupRenderingTest(hooks);

    test("no participants", async function (assert) {
      this.thread = fabricators.thread();
      await render(hbs`<ChatThreadParticipants @thread={{this.thread}} />`);

      assert.dom(".chat-thread-participants").doesNotExist();
    });

    test("@includeOriginalMessageUser=true", async function (assert) {
      const originalMessageUser = fabricators.user({ username: "bob" });
      this.thread = fabricators.thread({
        original_message: fabricators.message({ user: originalMessageUser }),
        preview: fabricators.threadPreview({
          channel: this.channel,
          participant_users: [
            originalMessageUser,
            fabricators.user({ username: "alice" }),
          ],
        }),
      });

      await render(hbs`<ChatThreadParticipants @thread={{this.thread}} />`);

      assert.dom(".chat-user-avatar[data-username]").exists({ count: 2 });
    });

    test("@includeOriginalMessageUser=false", async function (assert) {
      const originalMessageUser = fabricators.user({ username: "bob" });
      this.thread = fabricators.thread({
        original_message: fabricators.message({ user: originalMessageUser }),
        preview: fabricators.threadPreview({
          channel: this.channel,
          participant_users: [
            originalMessageUser,
            fabricators.user({ username: "alice" }),
          ],
        }),
      });

      await render(
        hbs`<ChatThreadParticipants @thread={{this.thread}} @includeOriginalMessageUser={{false}} />`
      );

      assert.dom('.chat-user-avatar[data-username="bob"]').doesNotExist();
      assert.dom('.chat-user-avatar[data-username="alice"]').exists();
    });
  }
);
