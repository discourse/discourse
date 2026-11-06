import { click, fillIn, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Event onebox", function (needs) {
  needs.user({ has_chat_enabled: true });
  needs.settings({
    chat_enabled: true,
    discourse_events_enabled: true,
    discourse_post_event_enabled: true,
    enable_markdown_linkify: true,
  });

  let eventRequests;
  let topicJson;
  const event = {
    id: 900,
    name: "Board game night",
    starts_at: "2026-09-20T18:00:00Z",
    ends_at: "2026-09-20T20:00:00Z",
    timezone: "UTC",
    status: "public",
    post: { id: 900, url: "/t/example/123", topic: { id: 123 } },
    creator: { username: "bob", id: 5 },
    can_update_attendance: true,
    should_display_invitees: true,
    sample_invitees: [],
    stats: { going: 1, interested: 0, invited: 0, not_going: 0 },
  };
  needs.hooks.beforeEach(() => {
    eventRequests = 0;
    topicJson = cloneJSON(topicFixtures["/t/280/1.json"]);
  });
  needs.pretender((server, helper) => {
    server.get("/chat/api/me/channels", () =>
      helper.response({
        direct_message_channels: [],
        public_channels: [
          {
            id: 11,
            title: "Events",
            chatable_id: 1,
            chatable_type: "Category",
            meta: { message_bus_last_ids: {} },
            current_user_membership: {
              following: true,
              last_read_message_id: 2,
            },
            chatable: { id: 1, color: "0088CC", name: "Events" },
          },
        ],
        meta: { message_bus_last_ids: {} },
        tracking: {
          channel_tracking: {
            11: { unread_count: 0, mention_count: 0 },
          },
          thread_tracking: {},
        },
      })
    );
    server.get("/chat/api/channels/11/messages", () =>
      helper.response({
        messages: [
          {
            id: 1,
            message: "Event topic",
            cooked: `
              <aside class="quote" data-topic="123" data-post="1">
                <div class="title">Event topic</div>
                <blockquote>Board game night</blockquote>
              </aside>
            `,
            created_at: "2026-09-01T10:00:00.000Z",
            user: { id: 5, username: "bob" },
          },
          {
            id: 2,
            message: "Ordinary topic",
            cooked: `
              <aside class="quote" data-topic="124" data-post="1">
                <div class="title">Ordinary topic</div>
                <blockquote>Preview text</blockquote>
              </aside>
            `,
            created_at: "2026-09-01T10:01:00.000Z",
            user: { id: 5, username: "bob" },
          },
        ],
        meta: { can_delete_self: true },
      })
    );
    server.post("/chat/api/channels/11/drafts", () => helper.response({}));
    server.get("/t/280.json", () => helper.response(topicJson));
    server.get("/t/280/:post_number.json", () => helper.response(topicJson));
    server.get("/discourse-post-event/events/900", () =>
      helper.response({ event })
    );
    server.get("/onebox", (request) => {
      const topicId = request.queryParams.url.split("/").pop();
      return [
        200,
        { "Content-Type": "text/html" },
        `
          <aside class="quote" data-topic="${topicId}" data-post="1">
            <div class="title">Example topic</div>
            <blockquote>Preview text</blockquote>
          </aside>
        `,
      ];
    });
    server.get("/discourse-post-event/events", (request) => {
      eventRequests++;
      const events = request.queryParams.topic_id === "123" ? [event] : [];
      return helper.response({ events });
    });
  });

  test("event topics show the read-only event card in both composer modes", async function (assert) {
    const url = `${window.location.origin}/t/example/123`;
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(".d-editor-input", `${url}\n\nEditable text`);
    await waitFor(".d-editor-preview .discourse-post-event-widget");

    assert
      .dom(".d-editor-preview .discourse-post-event-widget .event-date .day")
      .exists("the markdown preview renders the event card's date box");
    assert
      .dom(".d-editor-preview .discourse-post-event-widget .name")
      .hasText(event.name);
    assert
      .dom(".d-editor-preview .going-button")
      .doesNotExist("the preview card has no RSVP controls");

    await click(".composer-toggle-switch");
    await waitFor(".onebox-wrapper .discourse-post-event-widget");

    assert
      .dom(".onebox-wrapper .discourse-post-event-widget .event-date .day")
      .exists("the rich editor renders the same card");
    assert
      .dom(".onebox-wrapper .discourse-post-event-widget .name")
      .hasText(event.name);
    assert.strictEqual(
      eventRequests,
      1,
      "the event is fetched once per topic across both modes"
    );

    await click(".composer-toggle-switch");
    assert
      .dom(".d-editor-input")
      .hasValue(
        `${url}\n\nEditable text`,
        "switching modes preserves the source URL"
      );
  });

  test("ordinary topics keep the standard onebox in both composer modes", async function (assert) {
    const url = `${window.location.origin}/t/example/124`;
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(".d-editor-input", `${url}\n\nEditable text`);

    assert
      .dom(".d-editor-preview aside.quote")
      .exists("the markdown preview keeps the server onebox");
    assert.dom(".d-editor-preview .discourse-post-event-widget").doesNotExist();

    await click(".composer-toggle-switch");

    assert
      .dom(".ProseMirror aside.quote")
      .hasStyle(
        { whiteSpace: "normal" },
        "the rich editor keeps the server onebox, without editor whitespace"
      );
    assert.dom(".ProseMirror .discourse-post-event-widget").doesNotExist();
  });

  test("published event oneboxes retain the interactive event card", async function (assert) {
    const post = topicJson.post_stream.posts[0];
    post.cooked = `
      <aside class="quote" data-topic="123" data-post="1">
        <div class="title">Event topic</div><blockquote>Board game night</blockquote>
      </aside>
      <aside class="quote" data-topic="124" data-post="1">
        <div class="title">Ordinary topic</div><blockquote>Preview text</blockquote>
      </aside>
    `;
    post.event_oneboxes = { 123: event };

    await visit("/t/internationalization-localization/280");

    assert
      .dom("#post_1 .discourse-post-event-onebox .discourse-post-event-widget")
      .exists("the confirmed event is decorated with its interactive card");
    assert
      .dom("#post_1 .discourse-post-event-onebox .going-button")
      .exists("the published card keeps its RSVP controls");
    assert
      .dom("#post_1 .discourse-post-event-onebox .name a")
      .hasText(event.name, "the card links to the event");
    assert
      .dom('#post_1 aside.quote[data-topic="124"]')
      .includesText(
        "Preview text",
        "ordinary topic previews retain core rendering"
      );
  });

  test("event topics show the interactive event card in chat", async function (assert) {
    await visit("/chat/c/events/11");
    await waitFor(".discourse-post-event-onebox .discourse-post-event-widget");

    assert
      .dom(".discourse-post-event-onebox .event-date .day")
      .exists("the chat card renders the event date");
    assert
      .dom(".discourse-post-event-onebox .name")
      .hasText(event.name, "the chat card links to the event");
    assert
      .dom(".discourse-post-event-onebox .going-button")
      .exists("the chat card keeps its RSVP controls");
    assert
      .dom('aside.quote[data-topic="124"]')
      .includesText(
        "Preview text",
        "ordinary topic oneboxes retain core rendering"
      );
  });
});
