import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatThreadParticipants from "discourse/plugins/chat/discourse/components/chat-thread-participants";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | <ChatThreadParticipants />",
  function (hooks) {
    setupRenderingTest(hooks);

    test("no participants", async function (assert) {
      const self = this;

      this.thread = new ChatFabricators(getOwner(this)).thread();
      await render(
        <template><ChatThreadParticipants @thread={{self.thread}} /></template>
      );

      assert.dom(".chat-thread-participants").doesNotExist();
    });

    test("@includeOriginalMessageUser=true", async function (assert) {
      const self = this;

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
        <template><ChatThreadParticipants @thread={{self.thread}} /></template>
      );

      assert.dom(".chat-user-avatar[data-username]").exists({ count: 2 });
    });

    test("@includeOriginalMessageUser=false", async function (assert) {
      const self = this;

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
        <template>
          <ChatThreadParticipants
            @thread={{self.thread}}
            @includeOriginalMessageUser={{false}}
          />
        </template>
      );

      assert.dom('.chat-user-avatar[data-username="bob"]').doesNotExist();
      assert.dom('.chat-user-avatar[data-username="alice"]').exists();
    });
  }
);
