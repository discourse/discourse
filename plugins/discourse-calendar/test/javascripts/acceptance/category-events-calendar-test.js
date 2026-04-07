import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Discourse Calendar - Category Events Calendar", function (needs) {
  needs.user();
  needs.settings({
    calendar_enabled: true,
    discourse_post_event_enabled: true,
    events_calendar_categories: "1",
    calendar_categories: "",
  });

  needs.pretender((server, helper) => {
    server.get("/discourse-post-event/events/:id", () => {
      return helper.response({
        event: {
          id: 67501,
          starts_at: moment()
            .tz("Asia/Calcutta")
            .add(1, "days")
            .format("YYYY-MM-DDT15:14:00.000Z"),
          ends_at: moment()
            .tz("Asia/Calcutta")
            .add(1, "days")
            .format("YYYY-MM-DDT16:14:00.000Z"),
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
          recurrence: "every_day",
          creator: { id: 1, username: "admin", name: "Admin" },
          status: "public",
          should_display_invitees: false,
        },
      });
    });

    server.get("/discourse-post-event/events", () => {
      return helper.response({
        events: [
          {
            id: 67501,
            starts_at: moment()
              .tz("Asia/Calcutta")
              .add(1, "days")
              .format("YYYY-MM-DDT15:14:00.000Z"),
            ends_at: moment()
              .tz("Asia/Calcutta")
              .add(1, "days")
              .format("YYYY-MM-DDT16:14:00.000Z"),
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
            recurrence: "every_day",
            rrule: `DTSTART:${moment().format("YYYYMMDDTHHmmss")}Z\nRRULE:FREQ=DAILY;INTERVAL=1;UNTIL=${moment().add(2, "days").format("YYYYMMDD")}`,
            occurrences: [
              {
                starts_at: moment()
                  .tz("Asia/Calcutta")
                  .add(1, "days")
                  .format("YYYY-MM-DDT15:14:00.000Z"),
                ends_at: moment()
                  .tz("Asia/Calcutta")
                  .add(1, "days")
                  .format("YYYY-MM-DDT16:14:00.000Z"),
              },
              {
                starts_at: moment()
                  .tz("Asia/Calcutta")
                  .add(2, "days")
                  .format("YYYY-MM-DDT15:14:00.000Z"),
                ends_at: moment()
                  .tz("Asia/Calcutta")
                  .add(2, "days")
                  .format("YYYY-MM-DDT16:14:00.000Z"),
              },
            ],
          },
          {
            id: 67502,
            starts_at: moment()
              .tz("Asia/Calcutta")
              .add(2, "days")
              .format("YYYY-MM-DDT15:14:00.000Z"),
            ends_at: moment()
              .tz("Asia/Calcutta")
              .add(2, "days")
              .format("YYYY-MM-DDT16:14:00.000Z"),
            timezone: "Asia/Calcutta",
            post: {
              id: 67502,
              post_number: 1,
              url: "/t/this-is-an-event/18450/1",
              topic: {
                id: 18450,
                title: "This is an event",
              },
            },
            name: "Awesome Event 2",
            occurrences: [
              {
                starts_at: moment()
                  .tz("Asia/Calcutta")
                  .add(2, "days")
                  .format("YYYY-MM-DDT15:14:00.000Z"),
                ends_at: moment()
                  .tz("Asia/Calcutta")
                  .add(2, "days")
                  .format("YYYY-MM-DDT16:14:00.000Z"),
              },
            ],
          },
          {
            id: 67502,
            starts_at: moment()
              .tz("Asia/Calcutta")
              .add(2, "days")
              .format("YYYY-MM-DDT15:14:00.000Z"),
            ends_at: moment()
              .tz("Asia/Calcutta")
              .add(2, "days")
              .format("YYYY-MM-DDT16:14:00.000Z"),
            timezone: "Asia/Calcutta",
            post: {
              id: 67502,
              post_number: 1,
              url: "/t/this-is-an-event/18451/1",
              topic: {
                id: 18451,
                title: "This is an event",
              },
            },
            name: "Awesome Event 3<script>alert('my awesome event');</script>",
            occurrences: [
              {
                starts_at: moment()
                  .tz("Asia/Calcutta")
                  .add(2, "days")
                  .format("YYYY-MM-DDT15:14:00.000Z"),
                ends_at: moment()
                  .tz("Asia/Calcutta")
                  .add(2, "days")
                  .format("YYYY-MM-DDT16:14:00.000Z"),
              },
            ],
          },
        ],
      });
    });
  });

  test("event name is escaped correctly", async function (assert) {
    await visit("/c/bug/1");

    assert
      .dom(".fc-daygrid-event-harness a[href='/t/-/18451/1'] .fc-event-title")
      .hasText(
        "Awesome Event 3<script>alert('my awesome event');</script>",
        "Elements should be escaped and appear as text rather than be the actual element."
      );
  });

  test("shows event calendar on category page", async function (assert) {
    await visit("/c/bug/1?foobar=true");

    assert
      .dom("#category-events-calendar")
      .exists("Events calendar div exists.");
    assert.dom(".fc").exists("FullCalendar is loaded.");
  });

  test("uses current locale to display calendar weekday names", async function (assert) {
    I18n.locale = "pt_BR";

    await visit("/c/bug/1");

    assert.deepEqual(
      [...document.querySelectorAll(".fc-col-header-cell-cushion")].map(
        (el) => el.innerText
      ),
      ["SEG.", "TER.", "QUA.", "QUI.", "SEX.", "SÁB.", "DOM."],
      "Week days are translated in the calendar header"
    );

    I18n.locale = "en";
  });

  test("event calendar shows recurrent events", async function (assert) {
    await visit("/c/bug/1");

    const [first, second] = [
      ...document.querySelectorAll(".fc-daygrid-event-harness"),
    ];

    assert.dom(".fc-event-title", first).hasText("Awesome Event");
    assert.dom(".fc-event-title", second).hasText("Awesome Event");

    const firstCell = first.closest("td");
    const secondCell = second.closest("td");

    assert.notStrictEqual(
      firstCell,
      secondCell,
      "events are in different days"
    );
  });

  test("recurring events show a visual indicator", async function (assert) {
    await visit("/c/bug/1");

    const recurringEvent = document.querySelector(
      ".fc-daygrid-event-harness a[href='/t/-/18449/1']"
    );
    assert
      .dom(recurringEvent)
      .hasClass("fc-recurring-event", "recurring event has the CSS class");
    assert
      .dom(".d-icon-arrows-rotate", recurringEvent)
      .exists("recurring event shows the recurring icon");

    const nonRecurringEvent = document.querySelector(
      ".fc-daygrid-event-harness a[href='/t/-/18450/1']"
    );
    assert
      .dom(nonRecurringEvent)
      .doesNotHaveClass(
        "fc-recurring-event",
        "non-recurring event does not have the CSS class"
      );
    assert
      .dom(".d-icon-arrows-rotate", nonRecurringEvent)
      .doesNotExist("non-recurring event does not show the recurring icon");
  });

  test("clicking an event shows a popup instead of navigating away", async function (assert) {
    await visit("/c/bug/1");

    const eventLink = document.querySelector(
      ".fc-daygrid-event-harness a[href='/t/-/18449/1']"
    );
    assert.notStrictEqual(eventLink, null, "event link exists");

    await click(eventLink);

    assert
      .dom(".discourse-post-event")
      .exists("event popup is shown after clicking");
    assert
      .dom("#category-events-calendar")
      .exists("still on the category page after clicking");
  });

  test("event popup shows recurrence info for recurring events", async function (assert) {
    await visit("/c/bug/1");

    const eventLink = document.querySelector(
      ".fc-daygrid-event-harness a[href='/t/-/18449/1']"
    );
    await click(eventLink);

    assert
      .dom(".event-recurrence")
      .exists("recurrence section is shown in the popup");
    assert
      .dom(".event-recurrence .d-icon-arrows-rotate")
      .exists("recurrence section has the recurring icon");
    assert
      .dom(".event-recurrence")
      .hasText("Every day", "recurrence section shows the correct label");
  });
});
