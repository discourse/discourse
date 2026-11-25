import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { tomorrow } from "discourse/lib/time-utils";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Upcoming Events Calendar", function (needs) {
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
    discourse_events_enabled: true,
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
            occurrences: [
              {
                starts_at: tomorrow().add(1, "hour"),
                ends_at: null,
              },
              {
                starts_at: tomorrow().add(1, "day").add(1, "hour"),
                ends_at: null,
              },
            ],
          },
          {
            id: 67502,
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
            occurrences: [
              {
                starts_at: tomorrow(),
                ends_at: null,
              },
            ],
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

    const [first, second] = [
      ...document.querySelectorAll(
        ".fc-daygrid-event-harness .fc-daygrid-event-dot"
      ),
    ];
    assert
      .dom(first)
      .hasStyle(
        { borderColor: "rgb(190, 10, 10)" },
        "Event item uses the proper color from category 1"
      );

    assert
      .dom(second)
      .hasStyle(
        { borderColor: "rgb(15, 120, 190)" },
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

const eventsTab = '.mobile-tab-bar__tab[data-key="upcoming-events"]';
const footerViews = ".mobile-tab-bar__views";

let personalEventChecks = 0;

// `hasPersonalEvents` answers whether the user has events of their own at all,
// which can differ from what the day being shown holds
function stubCalendarOccurrences(
  personalTimes,
  { hasPersonalEvents = personalTimes.length > 0 } = {}
) {
  personalEventChecks = 0;
  pretender.get("/discourse-post-event/events", ({ queryParams }) => {
    let times = queryParams.attending_user ? personalTimes : ["10:00", "14:00"];

    if (!queryParams.after) {
      personalEventChecks++;
      times = hasPersonalEvents ? ["10:00"] : [];
    }

    const date = queryParams.after?.slice(0, 10) ?? "2026-05-12";
    return response({
      events: times.length
        ? [
            {
              id: 42,
              name: "Community meetup",
              post: { post_number: 1, topic: { id: 42 } },
              timezone: "UTC",
              occurrences: times.map((time) => ({
                starts_at: `${date}T${time}:00Z`,
              })),
            },
          ]
        : [],
    });
  });
}

function setupMobileCalendar(needs, settings = {}) {
  needs.mobileView();
  needs.settings({
    discourse_events_enabled: true,
    discourse_post_event_enabled: true,
    sidebar_show_upcoming_events: true,
    mobile_footer_navigation: true,
    calendar_upcoming_events_default_view: "day",
    ...settings,
  });
  needs.pretender((server, helper) => {
    server.get("/discourse-post-event/events", () =>
      helper.response({ events: [] })
    );
  });
}

acceptance("Upcoming events in the mobile footer", function (needs) {
  needs.user();
  setupMobileCalendar(needs);

  test("the forum menu leaves Events to its footer tab", async function (assert) {
    await visit("/latest");
    await click(".mobile-tab-bar__menu");
    await click(".sidebar-more-section-links-details-summary");

    assert.dom(eventsTab).exists("the footer links to Events");
    assert
      .dom(".sidebar-section-link[data-link-name='upcoming-events']")
      .doesNotExist("Events appears once in mobile navigation");
  });

  test("opens an empty calendar without view tabs", async function (assert) {
    await visit("/latest");
    assert
      .dom(eventsTab)
      .hasText(i18n("discourse_events.title"), "names the Events tab");
    assert
      .dom(`${eventsTab} .d-icon-calendar-day`)
      .exists("uses the calendar icon");
    await click(eventsTab);

    assert
      .dom(eventsTab)
      .hasAttribute("aria-current", "page", "selects Events");
    assert
      .dom(`${footerViews} a`)
      .doesNotExist("an empty calendar has no view tabs");
  });

  test("leaves the view tabs out for a user with no events of their own", async function (assert) {
    stubCalendarOccurrences([]);
    await visit("/upcoming-events/day/2026/5/12");

    assert
      .dom(".fc-timegrid-event .fc-event-title")
      .hasText("Community meetup", "shows the public events");
    assert.dom(`${footerViews} a`).doesNotExist("My events would be empty");
  });

  test("keeps My events open on a day without personal events", async function (assert) {
    stubCalendarOccurrences([], { hasPersonalEvents: false });
    await visit("/upcoming-events/mine/day/2026/5/12");

    assert.strictEqual(
      currentURL(),
      "/upcoming-events/mine/day/2026/5/12",
      "stays in the view the link asked for"
    );
    assert
      .dom(`${footerViews} a[href*="/mine/"]`)
      .hasAttribute("aria-current", "page", "names the view that's open");
    assert
      .dom(`${footerViews} a:not([href*="/mine/"])`)
      .exists("leaves a way back to All events");
  });

  test("keeps the view tabs while paging to a day without personal events", async function (assert) {
    stubCalendarOccurrences([], { hasPersonalEvents: true });
    await visit("/upcoming-events/mine/day/2026/5/12");
    await click(".fc-next-button");

    assert.strictEqual(
      currentURL(),
      "/upcoming-events/mine/day/2026/5/13",
      "stays in My events"
    );
    await click(`${footerViews} a:not([href*="/mine/"])`);
    await click(".fc-next-button");

    assert
      .dom(`${footerViews} a`)
      .exists({ count: 2 }, "the tabs stay while paging All events");
    assert.strictEqual(
      personalEventChecks,
      1,
      "checks for the user's own events once"
    );
  });

  test("switches views at the selected date when only some occurrences are personal", async function (assert) {
    stubCalendarOccurrences(["10:00"]);
    await visit("/upcoming-events/day/2026/5/12");

    assert
      .dom(`${footerViews} a[aria-current="page"]`)
      .hasText(
        i18n("discourse_post_event.upcoming_events.all_events"),
        "opens All events"
      );
    assert
      .dom(".fc-mineEvents-button")
      .doesNotExist("the footer holds the view switcher");

    await click(".fc-next-button");
    const allURL = currentURL();
    await click(`${footerViews} a[href*="/mine/"]`);
    assert.strictEqual(
      currentURL(),
      allURL.replace("/upcoming-events/", "/upcoming-events/mine/"),
      "keeps the selected day and calendar view"
    );
    assert
      .dom(`${footerViews} a[aria-current="page"]`)
      .hasText(
        i18n("discourse_post_event.upcoming_events.my_events"),
        "selects My events"
      );
    assert
      .dom(eventsTab)
      .hasAttribute("aria-current", "page", "both views belong to Events");
    await click(`${footerViews} a:not([href*="/mine/"])`);
    assert.strictEqual(
      currentURL(),
      allURL,
      "returns to the same day in All events"
    );
  });
});

acceptance(
  "Upcoming events in the mobile footer for visitors",
  function (needs) {
    setupMobileCalendar(needs);

    test("opens the public calendar without a personal view", async function (assert) {
      await visit("/latest");
      await click(eventsTab);
      assert
        .dom("#upcoming-events-calendar")
        .exists("opens the public calendar");
      assert
        .dom(`${footerViews} a`)
        .doesNotExist("visitors have only the public view");
      assert
        .dom(".fc-mineEvents-button")
        .doesNotExist("hides the personal calendar control");
    });
  }
);

acceptance("Upcoming events hidden from navigation", function (needs) {
  needs.user();
  setupMobileCalendar(needs, { sidebar_show_upcoming_events: false });

  test("keeps the views on the calendar when its navigation link is disabled", async function (assert) {
    await visit("/upcoming-events/day/2026/5/12");
    assert.dom(".mobile-tab-bar").exists("the site's mobile footer is enabled");
    assert
      .dom(eventsTab)
      .doesNotExist("respects the Upcoming events navigation setting");
    assert
      .dom(".fc-allEvents-button")
      .exists("keeps All events in the calendar toolbar");
    assert
      .dom(".fc-mineEvents-button")
      .exists("keeps My events in the calendar toolbar");
  });
});
