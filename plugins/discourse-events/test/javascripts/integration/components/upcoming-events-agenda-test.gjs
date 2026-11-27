import { click, find, render } from "@ember/test-helpers";
import moment from "moment";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import UpcomingEventsCalendar from "discourse/plugins/discourse-events/discourse/components/upcoming-events-calendar";

module("Integration | Component | UpcomingEventsAgenda", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  for (const timezone of ["America/New_York", "Pacific/Auckland"]) {
    test(`preserves the selected year in ${timezone}`, async function (assert) {
      this.currentUser.user_option.timezone = timezone;
      const routes = [];
      this.owner.lookup("service:router").replaceWith = (...args) =>
        routes.push(args);
      pretender.get("/discourse-post-event/events/agenda", () =>
        response({
          events: [],
          has_earlier: false,
          has_later: false,
        })
      );
      const initialDate = Date.parse("2026/1/1");

      await render(
        <template>
          <UpcomingEventsCalendar
            @initialDate={{initialDate}}
            @initialView="year"
          />
        </template>
      );

      assert
        .dom(".fc-toolbar-title")
        .hasText("2026", "opens the requested calendar year");
      assert.deepEqual(
        routes.at(-1).slice(1),
        ["year", 2026, 1, 1],
        "keeps the calendar date in the route"
      );
      await click(".fc-next-button");
      assert
        .dom(".fc-toolbar-title")
        .hasText("2027", "advances exactly one year");
      assert.deepEqual(
        routes.at(-1).slice(1),
        ["year", 2027, 1, 1],
        "routes to the next year"
      );
    });
  }

  test("keeps year navigation and hides controls for an empty year", async function (assert) {
    const requests = [];
    pretender.get("/discourse-post-event/events/agenda", ({ queryParams }) => {
      requests.push(queryParams);
      return response({
        events: [],
        next_cursor: null,
        has_earlier: false,
        has_later: false,
      });
    });
    await render(
      <template>
        <UpcomingEventsCalendar
          @initialDate="2026-11-27"
          @initialView="year"
          @updateRouteOnDatesChange={{false}}
        />
      </template>
    );
    assert
      .dom(".fc-listYear-view")
      .exists("uses the existing FullCalendar Year view");
    assert
      .dom(".upcoming-events-agenda__earlier")
      .doesNotExist("does not offer nonexistent history");
    assert
      .dom(".upcoming-events-agenda__later")
      .doesNotExist("does not offer nonexistent future events");
    await click(".fc-next-button");
    assert.strictEqual(
      requests.length,
      2,
      "fetches once for the newly selected year"
    );
    assert.strictEqual(
      moment.parseZone(requests[1].after).year(),
      2027,
      "moves to the next calendar year"
    );
    assert.strictEqual(
      requests[1].anchor,
      requests[1].after,
      "starts other years at January 1"
    );
    assert
      .dom(".fc-toolbar-title")
      .hasText("2027", "preserves the year heading");
  });

  test("starts today and loads each direction only on demand", async function (assert) {
    const requests = [];
    pretender.get("/discourse-post-event/events/agenda", ({ queryParams }) => {
      requests.push(queryParams);
      const earlier = queryParams.direction === "earlier";
      const laterPage = queryParams.cursor_id;
      const date = moment(queryParams.anchor).add(earlier ? -2 : 2, "days");
      return response({
        events: [event(earlier ? 3 : laterPage ? 2 : 1, date.toISOString())],
        next_cursor:
          !earlier && !laterPage ? { time: date.toISOString(), id: 1 } : null,
        has_earlier: !earlier,
        has_later: !earlier && !laterPage,
      });
    });

    await render(
      <template>
        <UpcomingEventsCalendar
          @categoryId={{2}}
          @includeSubcategories={{true}}
          @initialView="year"
          @updateRouteOnDatesChange={{false}}
        />
      </template>
    );

    assert.strictEqual(requests.length, 1, "fetches only the first page");
    assert.strictEqual(
      moment(requests[0].anchor)
        .tz(this.currentUser.user_option.timezone || moment.tz.guess())
        .format("YYYY-MM-DD"),
      moment()
        .tz(this.currentUser.user_option.timezone || moment.tz.guess())
        .format("YYYY-MM-DD"),
      "starts on today in the user's timezone"
    );
    assert.strictEqual(
      moment.parseZone(requests[0].anchor).format("YYYY-MM-DD"),
      moment()
        .tz(this.currentUser.user_option.timezone || moment.tz.guess())
        .format("YYYY-MM-DD"),
      "preserves the viewer's civil date for all-day and floating-time events"
    );
    assert
      .dom(".upcoming-events-agenda")
      .includesText("Event 1", "shows the first occurrence");

    assert.strictEqual(
      find(".upcoming-events-agenda__earlier").compareDocumentPosition(
        find(".fc-view-harness")
      ),
      Node.DOCUMENT_POSITION_FOLLOWING,
      "the earlier control precedes the event list"
    );
    assert
      .dom(".fc-header-toolbar .upcoming-events-agenda__earlier")
      .doesNotExist("keeps paging separate from calendar navigation");
    assert
      .dom(".upcoming-events-agenda__earlier .d-icon-chevron-up")
      .exists("earlier events use an upward arrow");
    assert
      .dom(".upcoming-events-agenda__later .d-icon-chevron-down")
      .exists("later events use a downward arrow");

    await click(".upcoming-events-agenda__later");
    assert.strictEqual(requests.length, 2, "one click makes one request");
    assert.strictEqual(
      requests[1].cursor_id,
      "1",
      "continues the occurrence cursor"
    );
    assert.strictEqual(
      requests[1].category_id,
      "2",
      "preserves the category filter"
    );
    assert.strictEqual(
      requests[1].include_subcategories,
      "true",
      "preserves subcategories"
    );
    assert
      .dom(".upcoming-events-agenda")
      .includesText("Event 2", "appends the next page");

    await click(".upcoming-events-agenda__earlier");
    assert.strictEqual(requests.length, 3, "loads history only when requested");
    assert.strictEqual(
      requests[2].anchor,
      requests[0].anchor,
      "history uses the same today anchor"
    );
    assert
      .dom(".fc-list-event")
      .includesText("Event 3", "prepends earlier events");
    assert
      .dom(".upcoming-events-agenda__earlier")
      .doesNotExist("removes the earlier control when history is exhausted");
    assert
      .dom(".upcoming-events-agenda__later")
      .doesNotExist("removes the later control when the last page is loaded");
    assert.strictEqual(
      moment.parseZone(requests[0].after).month(),
      0,
      "uses the calendar year's start"
    );
    assert.strictEqual(
      moment.parseZone(requests[0].before).month(),
      0,
      "stops at the next calendar year"
    );
  });

  test("renders grouped occurrences and hides later after an empty page", async function (assert) {
    const startsAt = moment().startOf("day").hour(12);
    const grouped = event(1, startsAt.toISOString());
    grouped.occurrences.push(
      ...event(1, startsAt.clone().add(1, "day").toISOString()).occurrences
    );
    let requests = 0;
    pretender.get("/discourse-post-event/events/agenda", () => {
      requests++;
      return response({
        events: requests === 1 ? [grouped] : [],
        next_cursor:
          requests === 1 ? { time: startsAt.toISOString(), id: 1 } : null,
        has_earlier: false,
        has_later: requests === 1,
      });
    });
    await render(
      <template>
        <UpcomingEventsCalendar
          @initialView="year"
          @updateRouteOnDatesChange={{false}}
        />
      </template>
    );
    assert
      .dom(".fc-list-event")
      .exists({ count: 2 }, "renders both occurrences from one event");
    await click(".upcoming-events-agenda__later");
    assert
      .dom(".upcoming-events-agenda__later")
      .doesNotExist("hides the control after an empty page");
    assert
      .dom(".fc-list-event")
      .exists({ count: 2 }, "retains the previously loaded occurrences");
    assert.strictEqual(
      requests,
      2,
      "does not request another page automatically"
    );
  });

  test("can retry an unsuccessful page without losing existing events", async function (assert) {
    let fail = false;
    const startsAt = moment()
      .tz(this.currentUser.user_option.timezone || moment.tz.guess())
      .startOf("day")
      .hour(12)
      .toISOString();
    pretender.get("/discourse-post-event/events/agenda", () =>
      fail
        ? response(500, {})
        : response({
            events: [event(1, startsAt)],
            next_cursor: null,
            has_earlier: false,
            has_later: true,
          })
    );
    await render(
      <template>
        <UpcomingEventsCalendar
          @initialView="year"
          @updateRouteOnDatesChange={{false}}
        />
      </template>
    );

    assert
      .dom(".fc-list-event")
      .exists({ count: 1 }, "initially renders one occurrence");
    fail = true;
    await click(".upcoming-events-agenda__later");
    assert.dom("[role=alert]").exists("shows a recoverable error");
    assert
      .dom(".upcoming-events-agenda")
      .includesText("Event 1", "keeps loaded events");
    fail = false;
    await click(".upcoming-events-agenda__later");
    assert.dom("[role=alert]").doesNotExist("retry clears the error");
    assert
      .dom(".fc-list-event")
      .exists({ count: 1 }, "deduplicates overlapping occurrences");
  });

  for (const view of ["day", "week", "month"]) {
    test(`${view} retains its existing single request`, async function (assert) {
      const requests = [];
      pretender.get("/discourse-post-event/events", ({ queryParams }) => {
        requests.push(queryParams);
        return response({ events: [] });
      });
      await render(
        <template>
          <UpcomingEventsCalendar
            @initialView={{view}}
            @updateRouteOnDatesChange={{false}}
          />
        </template>
      );

      assert.strictEqual(
        requests.length,
        1,
        "makes the original single request"
      );
      assert.false("page_size" in requests[0], "does not enable pagination");
      assert
        .dom(".upcoming-events-agenda")
        .doesNotExist("does not render the agenda");
    });
  }
});

function event(id, startsAt) {
  return {
    id,
    name: `Event ${id}`,
    post: { url: `/t/-/${id}`, post_number: 1, topic: { id } },
    occurrences: [
      {
        starts_at: startsAt,
        ends_at: moment(startsAt).add(1, "hour").toISOString(),
      },
    ],
  };
}
