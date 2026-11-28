import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ChatChannel from "discourse/plugins/chat/discourse/components/chat-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Integration | Component | ChatChannel", function (hooks) {
  setupRenderingTest(hooks);

  test("the latest date divider spans its messages as soon as the channel loads", async function (assert) {
    // The throttled pane resize can be skipped when the skeleton is replaced.
    const observe = ResizeObserver.prototype.observe;
    sinon
      .stub(ResizeObserver.prototype, "observe")
      .callsFake(function (target, options) {
        if (!target.classList.contains("chat-messages-container")) {
          observe.call(this, target, options);
        }
      });

    const channel = new ChatFabricators(this.owner).channel({ id: 1 });
    channel.currentUserMembership.following = true;
    channel.currentUserMembership.lastReadMessageId = 0;

    const author = {
      id: 2,
      username: "hawk",
      avatar_template: "/avatar/{size}.png",
    };
    pretender.get("/chat/api/channels/1/messages", () =>
      response({
        messages: [
          {
            id: 1,
            user: author,
            created_at: "2026-05-01T12:00:00Z",
            message: "Earlier message",
            cooked: "<p>Earlier message</p>",
          },
          {
            id: 2,
            user: author,
            created_at: "2026-05-03T12:00:00Z",
            message: "Longer message",
            cooked: "<p>Longer message</p>".repeat(40),
          },
        ],
        meta: { can_load_more_past: false, can_load_more_future: false },
      })
    );
    pretender.get("/chat/api/me/channels", () =>
      response({ direct_message_channels: [], public_channels: [] })
    );
    pretender.put("/chat/api/channels/1/read", () =>
      response({ success: true })
    );

    await render(<template><ChatChannel @channel={{channel}} /></template>);

    const divider = ".chat-message-separator-date[data-id='2']";
    assert.dom(divider).exists("the latest date divider is rendered");
    assert.true(
      find(divider).offsetHeight >=
        find(".chat-message-container[data-id='2']").offsetHeight,
      "the divider spans the message so the date can stick before any scroll input"
    );
  });
});
