import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";

module(
  "Discourse Chat | Component | <Chat::Thread::Participants />",
  function (hooks) {
    setupRenderingTest(hooks);

    test("no participants", async function (assert) {
      this.thread = fabricators.thread();
      await render(hbs`<Chat::Thread::Participants @thread={{this.thread}} />`);

      assert.dom(".chat-thread-participants").doesNotExist();
    });

    test("includeOriginalMessageUser=true", async function (assert) {
      const orignalMessageUser = fabricators.user({ username: "bob" });
      this.thread = fabricators.thread({
        original_message: fabricators.message({ user: orignalMessageUser }),
        preview: fabricators.threadPreview({
          channel: this.channel,
          participant_users: [
            orignalMessageUser,
            fabricators.user({ username: "alice" }),
          ],
        }),
      });

      await render(hbs`<Chat::Thread::Participants @thread={{this.thread}} />`);

      assert.dom('.chat-user-avatar [data-user-card="bob"]').exists();
      assert.dom('.chat-user-avatar [data-user-card="alice"]').exists();
    });

    test("includeOriginalMessageUser=false", async function (assert) {
      const orignalMessageUser = fabricators.user({ username: "bob" });
      this.thread = fabricators.thread({
        original_message: fabricators.message({ user: orignalMessageUser }),
        preview: fabricators.threadPreview({
          channel: this.channel,
          participant_users: [
            orignalMessageUser,
            fabricators.user({ username: "alice" }),
          ],
        }),
      });

      await render(
        hbs`<Chat::Thread::Participants @thread={{this.thread}} @includeOriginalMessageUser={{false}} />`
      );

      assert.dom('.chat-user-avatar [data-user-card="bob"]').doesNotExist();
      assert.dom('.chat-user-avatar [data-user-card="alice"]').exists();
    });
  }
);
