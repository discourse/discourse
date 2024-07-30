import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | <ChatThreadParticipants />",
  function (hooks) {
    setupRenderingTest(hooks);

    test("no participants", async function (assert) {
      this.thread = new ChatFabricators(getOwner(this)).thread();
      await render(hbs`<ChatThreadParticipants @thread={{this.thread}} />`);

      assert.dom(".chat-thread-participants").doesNotExist();
    });

    test("@includeOriginalMessageUser=true", async function (assert) {
      const originalMessageUser = new CoreFabricators(getOwner(this)).user({
        username: "bob",
      });
      this.thread = new ChatFabricators(getOwner(this)).thread({
        original_message: new ChatFabricators(getOwner(this)).message({
          user: originalMessageUser,
        }),
        preview: new ChatFabricators(getOwner(this)).threadPreview({
          channel: this.channel,
          participant_users: [
            originalMessageUser,
            new CoreFabricators(getOwner(this)).user({ username: "alice" }),
          ],
        }),
      });

      await render(hbs`<ChatThreadParticipants @thread={{this.thread}} />`);

      assert.dom(".chat-user-avatar[data-username]").exists({ count: 2 });
    });

    test("@includeOriginalMessageUser=false", async function (assert) {
      const originalMessageUser = new CoreFabricators(getOwner(this)).user({
        username: "bob",
      });
      this.thread = new ChatFabricators(getOwner(this)).thread({
        original_message: new ChatFabricators(getOwner(this)).message({
          user: originalMessageUser,
        }),
        preview: new ChatFabricators(getOwner(this)).threadPreview({
          channel: this.channel,
          participant_users: [
            originalMessageUser,
            new CoreFabricators(getOwner(this)).user({ username: "alice" }),
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
