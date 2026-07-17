import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatChannelPreviewCard from "discourse/plugins/chat/discourse/components/chat-channel-preview-card";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { LIVESTREAM_CHAT_CONTEXT } from "discourse/plugins/discourse-calendar/discourse/components/livestream/embeddable-chat-channel";

module("Discourse Calendar | Component | livestream-rsvp", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.channel = new ChatFabricators(getOwner(this)).channel({
      chatable_type: "Category",
    });
    this.channel.title = "livestream chat";
    this.channel.meta = { can_join_chat_channel: true };
    this.currentUser.set("has_chat_enabled", true);
    this.siteSettings.chat_enabled = true;

    this.setLivestreamTopic = (overrides = {}) => {
      this.channel.livestreamTopic = {
        id: 1,
        title: "Watching the birds",
        slug: "watching-the-birds",
        url: "/t/watching-the-birds/1",
        event_id: 99,
        can_update_attendance: true,
        watching_invitee_status: null,
        ...overrides,
      };
    };
  });

  test("replaces the join button with a linked RSVP message for livestream channels", async function (assert) {
    this.setLivestreamTopic();

    await render(
      <template><ChatChannelPreviewCard @channel={{this.channel}} /></template>
    );

    assert
      .dom(".livestream-rsvp__message a[href='/t/watching-the-birds/1']")
      .exists("links to the livestream topic");
    assert
      .dom(".chat-channel-preview-card__actions .livestream-rsvp__going-button")
      .exists("renders the RSVP button in the preview card actions");
    assert.dom(".toggle-channel-membership-button.-join").doesNotExist();
  });

  test("does not link the topic when rendered within the livestream topic", async function (assert) {
    this.setLivestreamTopic();

    await render(
      <template>
        <ChatChannelPreviewCard
          @channel={{this.channel}}
          @context={{LIVESTREAM_CHAT_CONTEXT}}
        />
      </template>
    );

    assert
      .dom(".livestream-rsvp__message")
      .hasText(i18n("discourse_calendar.livestream.chat.rsvp_to_event"));
    assert.dom(".livestream-rsvp__message a").doesNotExist();
  });

  test("keeps the default join button when the user cannot join the event", async function (assert) {
    this.setLivestreamTopic({ can_update_attendance: false });

    await render(
      <template><ChatChannelPreviewCard @channel={{this.channel}} /></template>
    );

    assert.dom(".toggle-channel-membership-button.-join").exists();
    assert.dom(".livestream-rsvp__going-button").doesNotExist();
  });

  test("keeps the default join button when the user is already going", async function (assert) {
    this.setLivestreamTopic({ watching_invitee_status: "going" });

    await render(
      <template><ChatChannelPreviewCard @channel={{this.channel}} /></template>
    );

    assert.dom(".toggle-channel-membership-button.-join").exists();
    assert.dom(".livestream-rsvp__going-button").doesNotExist();
  });

  test("keeps the default join button for regular channels", async function (assert) {
    await render(
      <template><ChatChannelPreviewCard @channel={{this.channel}} /></template>
    );

    assert.dom(".toggle-channel-membership-button.-join").exists();
    assert.dom(".livestream-rsvp__going-button").doesNotExist();
  });
});
