import { getOwner } from "@ember/owner";
import { click, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DiscoursePostEvent from "../../discourse/components/discourse-post-event";
import DiscoursePostEventEvent from "../../discourse/models/discourse-post-event-event";

function buildEvent(overrides = {}) {
  return DiscoursePostEventEvent.create({
    id: 1,
    // 2026-06-04 is a Thursday
    starts_at: "2026-06-04T14:00:00Z",
    ends_at: "2026-06-04T15:00:00Z",
    timezone: "UTC",
    status: "public",
    name: "Product team office hours",
    post: { id: 1, url: "/t/foo/1", topic: { id: 1 } },
    creator: { username: "bob", id: 5 },
    should_display_invitees: false,
    sample_invitees: [],
    ...overrides,
  });
}

module("Integration | Component | DiscoursePostEvent", function (hooks) {
  setupRenderingTest(hooks);

  function stubApi(event) {
    getOwner(this).unregister("service:discourse-post-event-api");
    getOwner(this).register(
      "service:discourse-post-event-api",
      {
        async event() {
          return event;
        },
      },
      { instantiate: false }
    );
  }

  test("interpolates the weekday into the recurrence label", async function (assert) {
    stubApi.call(this, buildEvent({ recurrence: "every_week" }));

    const event = { id: 1, startsAt: "2026-06-04T14:00:00Z" };
    await render(<template><DiscoursePostEvent @event={{event}} /></template>);
    await waitFor(".event-recurrence");

    assert
      .dom(".event-recurrence")
      .hasText(
        "Every Thursday",
        "renders the weekday instead of a missing placeholder"
      );
  });

  test("interpolates the ordinal and weekday into the monthly recurrence label", async function (assert) {
    stubApi.call(this, buildEvent({ recurrence: "every_month" }));

    const event = { id: 1, startsAt: "2026-06-04T14:00:00Z" };
    await render(<template><DiscoursePostEvent @event={{event}} /></template>);
    await waitFor(".event-recurrence");

    assert
      .dom(".event-recurrence")
      .hasText(
        "The first Thursday of every month",
        "renders both the ordinal and weekday placeholders"
      );
  });

  test("wires up the event image lightbox inside a topic", async function (assert) {
    stubApi.call(
      this,
      buildEvent({
        image_upload: { url: "/uploads/default/original/1X/event.png" },
      })
    );

    const event = { id: 1, startsAt: "2026-06-04T14:00:00Z" };
    await render(<template><DiscoursePostEvent @event={{event}} /></template>);
    await waitFor(".event-image a.lightbox");
    await click(".event-image a.lightbox");
    await waitFor(".pswp--open");

    assert.dom(".pswp--open").exists("opens the PhotoSwipe lightbox");

    await click(".pswp__button--close");
  });

  test("links the event image to the post when linkToPost is set", async function (assert) {
    stubApi.call(
      this,
      buildEvent({
        image_upload: { url: "/uploads/default/original/1X/event.png" },
      })
    );

    const event = { id: 1, startsAt: "2026-06-04T14:00:00Z" };
    await render(
      <template>
        <DiscoursePostEvent @event={{event}} @linkToPost={{true}} />
      </template>
    );
    await waitFor(".event-image");

    assert
      .dom(".event-image a.lightbox")
      .doesNotExist("does not wire up a lightbox in calendar contexts");
    assert
      .dom(".event-image a")
      .hasAttribute(
        "href",
        "/t/foo/1",
        "links the image to the event topic instead"
      );
  });

  test("derives the weekday from the date for all-day events, ignoring the timezone offset", async function (assert) {
    // Midnight UTC in a negative-offset timezone rolls back to the previous
    // day; an all-day event's weekday must come from the date, not the offset.
    stubApi.call(
      this,
      buildEvent({
        recurrence: "every_week",
        all_day: true,
        timezone: "America/New_York",
        starts_at: "2026-06-04T00:00:00Z",
      })
    );

    const event = { id: 1, startsAt: "2026-06-04T00:00:00Z" };
    await render(<template><DiscoursePostEvent @event={{event}} /></template>);
    await waitFor(".event-recurrence");

    assert
      .dom(".event-recurrence")
      .hasText("Every Thursday", "uses the date's weekday, not the prior day");
  });
});
