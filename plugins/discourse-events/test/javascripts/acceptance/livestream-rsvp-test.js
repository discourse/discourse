import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const CATEGORY = { id: 1, color: "ff0000", name: "livestream" };

const LIVESTREAM_TOPIC = {
  id: 1,
  title: "Watching the birds",
  slug: "watching-the-birds",
  url: "/t/watching-the-birds/1",
  event_id: 99,
  can_update_attendance: true,
  watching_invitee_status: null,
};

function channel({
  id = 11,
  livestreamTopic,
  following = false,
  ...overrides
}) {
  return {
    id,
    title: "livestream chat",
    slug: "livestream-chat",
    chatable_id: CATEGORY.id,
    chatable_type: "Category",
    chatable: CATEGORY,
    status: "open",
    memberships_count: 0,
    current_user_membership: { following },
    livestream_topic: livestreamTopic,
    meta: { can_join_chat_channel: true, message_bus_last_ids: {} },
    ...overrides,
  };
}

function livestream(overrides = {}) {
  return { ...LIVESTREAM_TOPIC, ...overrides };
}

acceptance("Events | Livestream RSVP", function (needs) {
  needs.user({ has_chat_enabled: true });
  needs.settings({
    chat_enabled: true,
    discourse_events_enabled: true,
    discourse_post_event_enabled: true,
  });

  needs.hooks.beforeEach(function () {
    pretender.get("/chat/api/me/channels", () =>
      response({
        direct_message_channels: [],
        public_channels: [],
        meta: { message_bus_last_ids: {} },
        tracking: { channel_tracking: {}, thread_tracking: {} },
      })
    );

    pretender.get("/chat/api/channels/:id/messages", () =>
      response({ messages: [], meta: { can_delete_self: true } })
    );

    pretender.post("/chat/api/channels/:id/drafts", () => response({}));
  });

  function previewCardFor(payload) {
    pretender.get("/chat/api/channels/11", () =>
      response({ channel: channel(payload) })
    );

    return visit("/chat/c/livestream-chat/11");
  }

  test("replaces the join button with a linked RSVP message for livestream channels", async function (assert) {
    await previewCardFor({ livestreamTopic: livestream() });

    assert
      .dom(".livestream-rsvp__message a[href='/t/watching-the-birds/1']")
      .exists("links to the livestream topic");
    assert
      .dom(".chat-channel-preview-card__actions .livestream-rsvp__going-button")
      .exists("renders the RSVP button in the preview card actions");
    assert.dom(".toggle-channel-membership-button.-join").doesNotExist();
  });

  test("keeps the default join button when the user cannot join the event", async function (assert) {
    await previewCardFor({
      livestreamTopic: livestream({ can_update_attendance: false }),
    });

    assert.dom(".toggle-channel-membership-button.-join").exists();
    assert.dom(".livestream-rsvp__going-button").doesNotExist();
  });

  test("keeps the default join button when the user is already going", async function (assert) {
    await previewCardFor({
      livestreamTopic: livestream({ watching_invitee_status: "going" }),
    });

    assert.dom(".toggle-channel-membership-button.-join").exists();
    assert.dom(".livestream-rsvp__going-button").doesNotExist();
  });

  test("keeps the default join button for regular channels", async function (assert) {
    await previewCardFor({});

    assert.dom(".toggle-channel-membership-button.-join").exists();
    assert.dom(".livestream-rsvp__going-button").doesNotExist();
  });

  test("does not render the RSVP replacement when the livestream topic is absent", async function (assert) {
    await previewCardFor({ livestreamTopic: undefined });

    assert.dom(".livestream-rsvp").doesNotExist();
    assert.dom(".livestream-rsvp__message").doesNotExist();
    assert.dom(".livestream-rsvp__going-button").doesNotExist();
    assert.dom(".toggle-channel-membership-button.-join").exists();
  });

  test("browse cards replace the join button for livestream channels", async function (assert) {
    pretender.get("/chat/api/channels", () =>
      response({
        channels: [
          channel({ id: 11, livestreamTopic: livestream() }),
          channel({
            id: 12,
            slug: "cannot-attend",
            livestreamTopic: livestream({ can_update_attendance: false }),
          }),
          channel({ id: 13, slug: "regular" }),
          channel({
            id: 14,
            slug: "already-a-member",
            livestreamTopic: livestream(),
            following: true,
          }),
        ],
        meta: {},
      })
    );

    await visit("/chat/browse");

    const card = (id) => `.chat-channel-card[data-channel-id="${id}"]`;

    assert
      .dom(`${card(11)} .chat-channel-card__cta .livestream-rsvp__going-button`)
      .exists("renders the RSVP button in the card CTA");
    assert
      .dom(`${card(11)} .toggle-channel-membership-button.-join`)
      .doesNotExist();

    assert
      .dom(`${card(12)} .toggle-channel-membership-button.-join`)
      .exists("keeps the join button when the user cannot join the event");
    assert.dom(`${card(12)} .livestream-rsvp__going-button`).doesNotExist();

    assert
      .dom(`${card(13)} .toggle-channel-membership-button.-join`)
      .exists("keeps the join button for regular channels");
    assert.dom(`${card(13)} .livestream-rsvp__going-button`).doesNotExist();

    assert
      .dom(`${card(14)} .toggle-channel-membership-button.-leave`)
      .exists("keeps the leave button for existing chat members");
    assert.dom(`${card(14)} .livestream-rsvp__going-button`).doesNotExist();
  });
});
