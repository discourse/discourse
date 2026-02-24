import { hash } from "@ember/helper";
import { click, currentURL, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { fakeTime, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import UpcomingEventsList, {
  DEFAULT_TIME_FORMAT,
} from "../../discourse/components/upcoming-events-list";

const today = "2100-02-01T08:00:00";
const tomorrowAllDay = "2100-02-02T00:00:00";
const laterThisMonth = "2100-02-22T08:00:00";
const nextWeek = "2100-02-09T08:00:00";

// Cross-month: Nov 28 - Dec 3
const crossMonthStart = "2100-11-28T00:00:00";
const crossMonthEnd = "2100-12-03T00:00:00";

// Cross-year: Dec 28 - Jan 3
const crossYearStart = "2100-12-28T00:00:00";
const crossYearEnd = "2101-01-03T00:00:00";

// Ongoing event: started yesterday, ends next week
const ongoingStart = "2100-01-25T00:00:00";
const ongoingEnd = "2100-02-09T00:00:00";

// Past event: already ended
const pastStart = "2100-01-01T00:00:00";
const pastEnd = "2100-01-15T00:00:00";

module("Integration | Component | upcoming-events-list", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.siteSettings.events_calendar_categories = "1";

    this.appEvents = this.owner.lookup("service:app-events");

    this.clock = fakeTime(today, null, true);
  });

  hooks.afterEach(function () {
    this.clock.restore();
  });

  test("empty state message", async function (assert) {
    pretender.get("/discourse-post-event/events", () => {
      return response({ events: [] });
    });

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    assert
      .dom(".upcoming-events-list__heading")
      .hasText(
        i18n("discourse_post_event.upcoming_events_list.title"),
        "displays the title"
      );

    await waitFor(".loading-container .spinner", { count: 0 });

    assert
      .dom(".upcoming-events-list__empty-message")
      .hasText(
        i18n("discourse_post_event.upcoming_events_list.empty"),
        "displays the empty list message"
      );
  });

  test("with events", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    assert
      .dom(".upcoming-events-list__heading")
      .hasText(
        i18n("discourse_post_event.upcoming_events_list.title"),
        "displays the title"
      );

    await waitFor(".loading-container .spinner", { count: 0 });

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-date .month")].map(
        (el) => el.innerText
      ),
      [
        moment(tomorrowAllDay).format("MMM").toUpperCase(),
        moment(laterThisMonth).format("MMM").toUpperCase(),
      ],
      "displays the correct month"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-date .day")].map(
        (el) => el.innerText
      ),
      [moment(tomorrowAllDay).format("D"), moment(laterThisMonth).format("D")],
      "displays the correct day"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-time")].map(
        (el) => el.innerText
      ),
      [
        i18n("discourse_post_event.upcoming_events_list.all_day"),
        moment(laterThisMonth).format(DEFAULT_TIME_FORMAT),
      ],
      "displays the formatted time"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-name")].map(
        (el) => el.innerText
      ),
      ["Awesome Event", "Another Awesome Event"],
      "displays the event name in the correct order"
    );

    assert
      .dom(".upcoming-events-list__view-all")
      .exists("displays the view-all link");
  });

  test("with multi-day events in same month", async function (assert) {
    pretender.get("/discourse-post-event/events", multiDayEventResponseHandler);

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    await waitFor(".loading-container .spinner", { count: 0 });

    assert
      .dom(".upcoming-events-list__event")
      .exists({ count: 1 }, "multi-day event appears only once");

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-name")].map(
        (el) => el.innerText
      ),
      ["Awesome Multiday Event"],
      "displays the multiday event name once"
    );

    const eventTime = document.querySelector(
      ".upcoming-events-list__event-time"
    ).innerText;

    // Feb 2 - Feb 9, 2100
    assert.true(eventTime.includes("February"), "contains month name");
    assert.true(eventTime.includes("2"), "contains start day");
    assert.true(eventTime.includes("9"), "contains end day");
    assert.true(eventTime.includes("2100"), "contains year");
    assert.false(eventTime.includes(":"), "shows date range, not time");
  });

  test("with cross-month multi-day events", async function (assert) {
    pretender.get("/discourse-post-event/events", () => {
      return response({
        events: [
          {
            id: 67504,
            starts_at: crossMonthStart,
            ends_at: crossMonthEnd,
            timezone: "UTC",
            post: {
              id: 67504,
              post_number: 1,
              url: "/t/cross-month-event/18452/1",
              topic: { id: 18452, title: "Cross month event" },
            },
            name: "Cross Month Event",
            category_id: 1,
          },
        ],
      });
    });

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    await waitFor(".loading-container .spinner", { count: 0 });

    const eventTime = document.querySelector(
      ".upcoming-events-list__event-time"
    ).innerText;

    // Nov 28 - Dec 3, 2100
    assert.true(eventTime.includes("November"), "contains start month");
    assert.true(eventTime.includes("28"), "contains start day");
    assert.true(eventTime.includes("December"), "contains end month");
    assert.true(eventTime.includes("3"), "contains end day");
    assert.true(eventTime.includes("2100"), "contains year");
  });

  test("with cross-year multi-day events", async function (assert) {
    pretender.get("/discourse-post-event/events", () => {
      return response({
        events: [
          {
            id: 67505,
            starts_at: crossYearStart,
            ends_at: crossYearEnd,
            timezone: "UTC",
            post: {
              id: 67505,
              post_number: 1,
              url: "/t/cross-year-event/18453/1",
              topic: { id: 18453, title: "Cross year event" },
            },
            name: "Cross Year Event",
            category_id: 1,
          },
        ],
      });
    });

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    await waitFor(".loading-container .spinner", { count: 0 });

    const eventTime = document.querySelector(
      ".upcoming-events-list__event-time"
    ).innerText;

    // Dec 28, 2100 - Jan 3, 2101
    assert.true(eventTime.includes("December"), "contains start month");
    assert.true(eventTime.includes("28"), "contains start day");
    assert.true(eventTime.includes("2100"), "contains start year");
    assert.true(eventTime.includes("January"), "contains end month");
    assert.true(eventTime.includes("3"), "contains end day");
    assert.true(eventTime.includes("2101"), "contains end year");
  });

  test("with ongoing multi-day events (started in past, ends in future)", async function (assert) {
    pretender.get("/discourse-post-event/events", () => {
      return response({
        events: [
          {
            id: 67506,
            starts_at: ongoingStart,
            ends_at: ongoingEnd,
            timezone: "UTC",
            post: {
              id: 67506,
              post_number: 1,
              url: "/t/ongoing-event/18454/1",
              topic: { id: 18454, title: "Ongoing event" },
            },
            name: "Ongoing Event",
            category_id: 1,
          },
        ],
      });
    });

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    await waitFor(".loading-container .spinner", { count: 0 });

    assert
      .dom(".upcoming-events-list__event")
      .exists({ count: 1 }, "ongoing event is displayed");

    assert
      .dom(".upcoming-events-list__event-name")
      .hasText("Ongoing Event", "displays the ongoing event");

    // Ongoing events should show at today's date
    const displayedDay = document.querySelector(
      ".upcoming-events-list__event-date .day"
    ).innerText;
    assert.strictEqual(
      displayedDay,
      moment(today).format("D"),
      "ongoing event is shown at today's date"
    );

    const eventTime = document.querySelector(
      ".upcoming-events-list__event-time"
    ).innerText;

    // Jan 25 - Feb 9, 2100
    assert.true(eventTime.includes("January"), "contains start month");
    assert.true(eventTime.includes("25"), "contains start day");
    assert.true(eventTime.includes("February"), "contains end month");
    assert.true(eventTime.includes("9"), "contains end day");
    assert.true(eventTime.includes("2100"), "contains year");
  });

  test("filters out events that have already ended", async function (assert) {
    pretender.get("/discourse-post-event/events", () => {
      return response({
        events: [
          {
            id: 67507,
            starts_at: pastStart,
            ends_at: pastEnd,
            timezone: "UTC",
            post: {
              id: 67507,
              post_number: 1,
              url: "/t/past-event/18455/1",
              topic: { id: 18455, title: "Past event" },
            },
            name: "Past Event",
            category_id: 1,
          },
          {
            id: 67508,
            starts_at: tomorrowAllDay,
            ends_at: null,
            timezone: "UTC",
            post: {
              id: 67508,
              post_number: 1,
              url: "/t/future-event/18456/1",
              topic: { id: 18456, title: "Future event" },
            },
            name: "Future Event",
            category_id: 1,
          },
        ],
      });
    });

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    await waitFor(".loading-container .spinner", { count: 0 });

    assert
      .dom(".upcoming-events-list__event")
      .exists({ count: 1 }, "only future event is displayed");

    assert
      .dom(".upcoming-events-list__event-name")
      .hasText("Future Event", "past event is filtered out");
  });

  test("Uses custom category name from 'map_events_title'", async function (assert) {
    pretender.get("/discourse-post-event/events", () => {
      return response({ events: [] });
    });

    this.siteSettings.map_events_title =
      '[{"category_slug": "announcements", "custom_title": "Upcoming Announcements"}]';

    await render(<template><UpcomingEventsList /></template>);
    this.appEvents.trigger("page:changed", { url: "/c/announcements" });

    assert
      .dom(".upcoming-events-list__heading")
      .hasText(
        "Upcoming Announcements",
        "sets 'Upcoming Announcements' as the title in 'c/announcements'"
      );
  });

  test("Uses default title for upcoming events list", async function (assert) {
    pretender.get("/discourse-post-event/events", () => {
      return response({ events: [] });
    });

    this.siteSettings.map_events_title = "";

    await render(<template><UpcomingEventsList /></template>);
    this.appEvents.trigger("page:changed", { url: "/c/announcements" });

    assert
      .dom(".upcoming-events-list__heading")
      .hasText(
        "Upcoming events",
        "sets default value as the title in 'c/announcements'"
      );
  });

  test("with events, view-all navigation", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    await waitFor(".loading-container .spinner", { count: 0 });

    assert
      .dom(".upcoming-events-list__view-all")
      .hasText(
        i18n("discourse_post_event.upcoming_events_list.view_all"),
        "displays the view-all link"
      );

    await click(".upcoming-events-list__view-all");

    assert.strictEqual(
      currentURL(),
      "/upcoming-events",
      "view-all link navigates to the upcoming-events page"
    );
  });

  test("with events, overridden time format", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);

    await render(
      <template>
        <UpcomingEventsList @params={{hash timeFormat="LLL"}} />
      </template>
    );

    this.appEvents.trigger("page:changed", { url: "/" });

    assert
      .dom(".upcoming-events-list__heading")
      .hasText(
        i18n("discourse_post_event.upcoming_events_list.title"),
        "displays the title"
      );

    await waitFor(".loading-container .spinner", { count: 0 });

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-time")].map(
        (el) => el.innerText
      ),
      [
        i18n("discourse_post_event.upcoming_events_list.all_day"),
        moment(laterThisMonth).format("LLL"),
      ],
      "displays the formatted time"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-name")].map(
        (el) => el.innerText
      ),
      ["Awesome Event", "Another Awesome Event"],
      "displays the event name"
    );
  });

  test("with an error response", async function (assert) {
    pretender.get("/discourse-post-event/events", () => {
      return response(500, {});
    });

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    assert
      .dom(".upcoming-events-list__heading")
      .hasText(
        i18n("discourse_post_event.upcoming_events_list.title"),
        "displays the title"
      );

    await waitFor(".loading-container .spinner", { count: 0 });

    assert
      .dom(".upcoming-events-list__error-message")
      .hasText(
        i18n("discourse_post_event.upcoming_events_list.error"),
        "displays the error message"
      );

    assert
      .dom(".upcoming-events-list__try-again")
      .hasText(
        i18n("discourse_post_event.upcoming_events_list.try_again"),
        "displays the try again button"
      );
  });

  test("with events, overridden count parameter", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);

    await render(
      <template><UpcomingEventsList @params={{hash count=1}} /></template>
    );

    this.appEvents.trigger("page:changed", { url: "/" });

    assert
      .dom(".upcoming-events-list__heading")
      .hasText(
        i18n("discourse_post_event.upcoming_events_list.title"),
        "displays the title"
      );

    await waitFor(".loading-container .spinner", { count: 0 });

    assert
      .dom(".upcoming-events-list__event")
      .exists(
        { count: 1 },
        "limits the resulting items to the count parameter"
      );

    assert
      .dom(".upcoming-events-list__event-name")
      .hasText("Awesome Event", "displays the event name");
  });

  test("with events, overridden upcomingDays parameter", async function (assert) {
    pretender.get("/discourse-post-event/events", twoEventsResponseHandler);

    await render(
      <template>
        <UpcomingEventsList @params={{hash upcomingDays=1}} />
      </template>
    );

    this.appEvents.trigger("page:changed", { url: "/" });

    await waitFor(".loading-container .spinner", { count: 0 });

    assert
      .dom(".upcoming-events-list__event")
      .exists(
        { count: 1 },
        "limits the results to started_at before the provided parameter"
      );

    assert
      .dom(".upcoming-events-list__event-name")
      .hasText("Awesome Event", "displays the event name");
  });
});

function twoEventsResponseHandler({ queryParams }) {
  let events = [
    {
      id: 67501,
      starts_at: tomorrowAllDay,
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
    },
    {
      id: 67502,
      starts_at: laterThisMonth,
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
  ];

  if (queryParams.limit) {
    events.splice(queryParams.limit);
  }

  if (queryParams.before) {
    events = events.filter((event) => {
      return moment(event.starts_at).isBefore(queryParams.before);
    });
  }

  return response({ events });
}

function multiDayEventResponseHandler({ queryParams }) {
  let events = [
    {
      id: 67503,
      starts_at: tomorrowAllDay,
      ends_at: nextWeek,
      timezone: "Asia/Calcutta",
      post: {
        id: 67501,
        post_number: 1,
        url: "/t/this-is-an-event/18451/1",
        topic: {
          id: 18449,
          title: "This is a multiday event",
        },
      },
      name: "Awesome Multiday Event",
      category_id: 1,
    },
  ];

  if (queryParams.limit) {
    events.splice(queryParams.limit);
  }

  if (queryParams.before) {
    events = events.filter((event) => {
      return moment(event.starts_at).isBefore(queryParams.before);
    });
  }

  return response({ events });
}
