import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Event onebox", function (needs) {
  needs.user();
  needs.settings({
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
    should_display_invitees: false,
    sample_invitees: [],
  };
  needs.hooks.beforeEach(() => {
    eventRequests = 0;
    topicJson = cloneJSON(topicFixtures["/t/280/1.json"]);
  });
  needs.pretender((server, helper) => {
    server.get("/t/280.json", () => helper.response(topicJson));
    server.get("/t/280/:post_number.json", () => helper.response(topicJson));
    server.get("/discourse-post-event/events/900", () =>
      helper.response({ event })
    );
    server.get("/onebox", (request) => {
      const isEvent = request.queryParams.url.endsWith("/123");
      return [
        200,
        { "Content-Type": "text/html" },
        `
          <aside class="quote" data-topic="${isEvent ? 123 : 124}" data-post="1">
            <div class="title">Example topic</div>
            <blockquote>
              ${isEvent ? '<div class="discourse-event-onebox"><p>Board game night</p><p>September 20, 2026 6:00 PM (UTC)</p></div>' : "Preview text"}
            </blockquote>
          </aside>
        `,
      ];
    });
    server.get("/discourse-post-event/events", () => {
      eventRequests++;
      return helper.response({ events: [] });
    });
  });

  [
    ["event", 123],
    ["ordinary", 124],
  ].forEach(([kind, id]) => {
    test(`${kind} topics use standard oneboxes in both composer modes`, async function (assert) {
      const url = `${window.location.origin}/t/example/${id}`;
      await visit("/t/internationalization-localization/280");
      await click("#topic-footer-buttons .btn.create");
      await fillIn(".d-editor-input", `${url}\n\nEditable text`);

      assert
        .dom(".d-editor-preview aside.quote")
        .exists("markdown renders the server preview");
      assert
        .dom(".d-editor-preview .discourse-post-event-onebox")
        .doesNotExist("no custom preview renderer is mounted");
      if (kind === "event") {
        assert
          .dom(".d-editor-preview .discourse-event-onebox")
          .includesText("Board game night", "the event details are rendered");
      }

      await click(".composer-toggle-switch");

      assert
        .dom(".onebox-wrapper aside.quote")
        .exists("rich text uses core's onebox wrapper");
      assert
        .dom(".onebox-wrapper aside.quote")
        .hasStyle(
          { whiteSpace: "normal" },
          "HTML indentation does not create blank lines"
        );
      assert
        .dom(".ProseMirror > p")
        .hasStyle(
          { whiteSpace: "break-spaces" },
          "editable whitespace is preserved"
        );
      assert.strictEqual(
        eventRequests,
        0,
        "topic previews need no additional event lookup"
      );

      await click(".composer-toggle-switch");
      assert
        .dom(".d-editor-input")
        .hasValue(
          `${url}\n\nEditable text`,
          "switching modes preserves the source URL"
        );
    });
  });

  test("published event oneboxes retain the interactive event card", async function (assert) {
    const post = topicJson.post_stream.posts[0];
    post.cooked = `
      <aside class="quote" data-topic="123" data-post="1">
        <div class="title">Event topic</div>
        <blockquote><div class="discourse-event-onebox">Board game night</div></blockquote>
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
      .dom("#post_1 .discourse-post-event-onebox .name a")
      .hasText(event.name, "the card links to the event");
    assert
      .dom('#post_1 aside.quote[data-topic="124"]')
      .includesText(
        "Preview text",
        "ordinary topic previews retain core rendering"
      );
  });
});
