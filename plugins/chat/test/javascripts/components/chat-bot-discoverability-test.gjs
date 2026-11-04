import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import AdminUser from "discourse/admin/models/admin-user";
import lazyHash from "discourse/helpers/lazy-hash";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import ChatBotDiscoverability from "discourse/plugins/chat/discourse/connectors/admin-user-details/chat-bot-discoverability";

module("Component | ChatBotDiscoverability", function (hooks) {
  setupRenderingTest(hooks);

  test("reverts a failed save", async function (assert) {
    const bot = AdminUser.create({
      id: -200,
      username: "test_bot",
      chat_discoverable: false,
    });
    sinon.stub(this.owner.lookup("service:dialog"), "alert");
    pretender.put("/chat/admin/bots/-200/discoverability.json", () => [
      500,
      { "Content-Type": "application/json" },
      JSON.stringify({ errors: ["Save failed"] }),
    ]);

    await render(
      <template>
        <ChatBotDiscoverability @outletArgs={{lazyHash model=bot}} />
      </template>
    );
    await click('[role="switch"]');

    assert.dom('[role="switch"]').hasAttribute("aria-checked", "false");
    assert.false(bot.chat_discoverable);
    assert.dom('[role="switch"]').isNotDisabled();
  });
});
