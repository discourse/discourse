import { hash } from "@ember/helper";
import Service from "@ember/service";
import { click, currentURL, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { fakeTime, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import UpcomingEventsList, {
  DEFAULT_TIME_FORMAT,
} from "../../discourse/components/upcoming-events-list";

class RouterStub extends Service {
  currentRoute = { attributes: { category: { id: 1, slug: "announcements" } } };
  currentRouteName = "discovery.latest";

  on() {}
  off() {}
}

const today = "2100-02-01T08:00:00";
const tomorrowAllDay = "2100-02-02T00:00:00";
const nextMonth = "2100-03-02T08:00:00";
const nextWeek = "2100-02-09T08:00:00";

module("Integration | Component | upcoming-events-list", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.unregister("service:router");
    this.owner.register("service:router", RouterStub);

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
        moment(nextMonth).format("MMM").toUpperCase(),
      ],
      "displays the correct month"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-date .day")].map(
        (el) => el.innerText
      ),
      [moment(tomorrowAllDay).format("D"), moment(nextMonth).format("D")],
      "displays the correct day"
    );

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-time")].map(
        (el) => el.innerText
      ),
      [
        i18n("discourse_post_event.upcoming_events_list.all_day"),
        moment(nextMonth).format(DEFAULT_TIME_FORMAT),
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

    assert
      .dom(".upcoming-events-list__view-all")
      .exists("displays the view-all link");
  });

  test("with multi-day events, standard formats", async function (assert) {
    pretender.get("/discourse-post-event/events", multiDayEventResponseHandler);

    await render(<template><UpcomingEventsList /></template>);

    this.appEvents.trigger("page:changed", { url: "/" });

    await waitFor(".loading-container .spinner", { count: 0 });

    assert.deepEqual(
      [...queryAll(".upcoming-events-list__event-name")].map(
        (el) => el.innerText
      ),
      [
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
        "Awesome Multiday Event",
      ],

      "displays the multiday event on all scheduled dates"
    );
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
        moment(nextMonth).format("LLL"),
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
      starts_at: nextMonth,
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
