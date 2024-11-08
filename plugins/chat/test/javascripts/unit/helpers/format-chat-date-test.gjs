import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formatChatDate from "discourse/plugins/chat/discourse/helpers/format-chat-date";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Discourse Chat | Unit | Helpers | format-chat-date", function (hooks) {
  setupRenderingTest(hooks);

  test("link to chat message", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel();
    const message = new ChatFabricators(getOwner(this)).message({ channel });

    await render(<template>{{formatChatDate message}}</template>);

    assert
      .dom(".chat-time")
      .hasAttribute("href", `/chat/c/-/${channel.id}/${message.id}`);
  });

  test("link to chat message thread", async function (assert) {
    const channel = new ChatFabricators(getOwner(this)).channel();
    const thread = new ChatFabricators(getOwner(this)).thread();
    const message = new ChatFabricators(getOwner(this)).message({
      channel,
      thread,
    });

    await render(<template>
      {{formatChatDate message (hash threadContext=true)}}
    </template>);

    assert
      .dom(".chat-time")
      .hasAttribute(
        "href",
        `/chat/c/-/${channel.id}/t/${thread.id}/${message.id}`
      );
  });
});
