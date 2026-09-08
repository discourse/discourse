import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import EmbeddableChatChannel from "discourse/plugins/discourse-events/discourse/components/livestream/embeddable-chat-channel";

// The rest of the RSVP cases are acceptance tests. This one needs the livestream context, which
// only exists when the chat channel is embedded in the topic it belongs to.
module("Events | Component | LivestreamRsvp", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.chat_enabled = true;
    this.currentUser.set("has_chat_enabled", true);

    pretender.get("/chat/api/channels/11", () =>
      response({
        channel: {
          id: 11,
          title: "livestream chat",
          slug: "livestream-chat",
          chatable_id: 1,
          chatable_type: "Category",
          chatable: { id: 1, color: "ff0000", name: "livestream" },
          status: "open",
          memberships_count: 0,
          current_user_membership: { following: false },
          livestream_topic: {
            id: 1,
            title: "Watching the birds",
            slug: "watching-the-birds",
            url: "/t/watching-the-birds/1",
            event_id: 99,
            can_update_attendance: true,
            watching_invitee_status: null,
          },
          meta: { can_join_chat_channel: true, message_bus_last_ids: {} },
        },
      })
    );

    pretender.get("/chat/api/channels/11/messages", () =>
      response({ messages: [], meta: { can_delete_self: true } })
    );

    pretender.post("/chat/api/channels/11/drafts", () => response({}));
  });

  test("does not link the topic when rendered within the livestream topic", async function (assert) {
    await render(
      <template><EmbeddableChatChannel @chatChannelId={{11}} /></template>
    );

    assert
      .dom(".livestream-rsvp__message")
      .hasText(i18n("discourse_events.livestream.chat.rsvp_to_event"));
    assert.dom(".livestream-rsvp__message a").doesNotExist();
  });
});
