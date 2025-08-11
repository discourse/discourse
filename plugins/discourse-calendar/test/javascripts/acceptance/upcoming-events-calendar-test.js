import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { tomorrow } from "discourse/lib/time-utils";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Calendar - Upcoming Events Calendar", function (needs) {
  needs.site({
    categories: [
      {
        id: 1,
        name: "Category 1",
        slug: "category-1",
        color: "0f78be",
      },
      {
        id: 2,
        name: "Category 2",
        slug: "category-2",
        color: "be0a0a",
      },
    ],
  });
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    events_calendar_categories: "1",
    calendar_categories: "",
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-post-event/events", () => {
      return helper.response({
        events: [
          {
            id: 67501,
            starts_at: tomorrow().add(1, "hour"),
            ends_at: null,
            timezone: "Asia/Calcutta",
            post: {
              id: 67501,
              post_number: 1,
              url: "/t/this-is-an-event/18449/1",
              topic: {
                id: 18449,
                title: "This is an event",
              },
            },
            name: "Awesome Event",
            category_id: 1,
            rrule: `DTSTART:${tomorrow().add(1, "hour").format("YYYYMMDDTHHmmss")}Z\nRRULE:FREQ=DAILY;INTERVAL=1;UNTIL=${tomorrow().add(2, "days").format("YYYYMMDD")}`,
          },
          {
            id: 67502,
            starts_at: tomorrow(),
            ends_at: null,
            timezone: "Asia/Calcutta",
            post: {
              id: 67501,
              post_number: 1,
              url: "/t/this-is-an-event-2/18450/1",
              topic: {
                id: 18449,
                title: "This is an event 2",
              },
            },
            name: "Another Awesome Event",
            category_id: 2,
          },
        ],
      });
    });
  });

  test("shows upcoming events calendar", async function (assert) {
    await visit("/upcoming-events");

    assert
      .dom("#upcoming-events-calendar")
      .exists("Upcoming Events calendar is shown");

    assert.dom(".fc").exists("FullCalendar is loaded");
  });

  test("upcoming events category colors", async function (assert) {
    await visit("/upcoming-events");

    const [first, second] = [...document.querySelectorAll(".fc-event")];
    assert
      .dom(first)
      .hasStyle(
        { backgroundColor: "rgb(190, 10, 10)" },
        "Event item uses the proper color from category 1"
      );

    assert
      .dom(second)
      .hasStyle(
        { backgroundColor: "rgb(15, 120, 190)" },
        "Event item uses the proper color from category 2"
      );
  });

  test("upcoming events calendar shows recurrent events", async function (assert) {
    await visit("/upcoming-events");

    const [, second, third] = [
      ...document.querySelectorAll(".fc-daygrid-event-harness"),
    ];
    assert.dom(".fc-event-title", second).hasText("Awesome Event");
    assert.dom(".fc-event-title", third).hasText("Awesome Event");

    const secondCell = second.closest("td");
    const thirdCell = third.closest("td");

    assert.notStrictEqual(
      secondCell,
      thirdCell,
      "events are in different days"
    );
  });
});
