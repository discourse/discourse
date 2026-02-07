import { set } from "@ember/object";
import { render } from "@ember/test-helpers";
import { module, skip, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import Dates from "../../discourse/components/discourse-post-event/dates";

module("Integration | Component | Dates", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    moment.tz.guess = () => "UTC";
    this.clock = fakeTime("2025-11-01T00:00:00Z", "UTC", true);

    // Set user's profile timezone to match browser timezone
    // to avoid timezone mismatch display in tests.
    // setupRenderingTest sets timezone to Australia/Brisbane by default.
    set(this.currentUser, "user_option", {
      ...this.currentUser.user_option,
      timezone: "UTC",
    });
  });

  hooks.afterEach(function () {
    this.clock?.restore();
  });

  const starts = {
    id: 123,
    startsAt: "2025-10-06T00:00:00Z",
  };
  const events = {
    currentYear: {
      starts,
      today: {
        ...starts,
        startsAt: "2025-11-01T08:00:00Z",
        endsAt: "2025-11-01T09:00:00Z",
      },
      yesterdayTomorrow: {
        ...starts,
        startsAt: "2025-10-31T08:00:00Z",
        endsAt: "2025-11-02T08:00:00Z",
      },
      weekdays: {
        ...starts,
        startsAt: "2025-11-01T14:00:00Z",
        endsAt: "2025-11-02T14:00:00Z",
      },
      endsSameDay: {
        ...starts,
        endsAt: "2025-10-06T01:00:00Z",
      },
      endsSameWeek: {
        ...starts,
        endsAt: "2025-10-10T00:00:00Z",
      },
      endsSameMonth: {
        ...starts,
        endsAt: "2025-10-20T00:00:00Z",
      },
      endsDiffMonth: {
        ...starts,
        endsAt: "2025-11-06T00:00:00Z",
      },
    },
    endsDiffYear: {
      ...starts,
      endsAt: "2026-01-06T00:00:00Z",
    },
  };

  module("dates without time", function () {
    test("formats events within calendar range (today/tomorrow)", async function (assert) {
      await render(
        <template>
          <div data-post-id="123">
            <Dates @event={{events.currentYear.weekdays}} />
          </div>
        </template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Today 2:00 PM → Tomorrow 2:00 PM",
          "events within calendar range should use relative formatting"
        );
    });

    test("formats start date", async function (assert) {
      await render(
        <template><Dates @event={{events.currentYear.starts}} /></template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6",
          "`startsAt` should not show current year and time"
        );
    });

    test("formats same week range", async function (assert) {
      await render(
        <template>
          <Dates @event={{events.currentYear.endsSameWeek}} />
        </template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6 → Fri, Oct 10",
          "`endAt` should be formatted with weekday, month and date"
        );
    });

    test("formats same month range", async function (assert) {
      await render(
        <template>
          <Dates @event={{events.currentYear.endsSameMonth}} />
        </template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6 → Mon, Oct 20",
          "`endAt` should be formatted with weekday, month and date"
        );
    });

    test("formats different months range", async function (assert) {
      await render(
        <template>
          <Dates @event={{events.currentYear.endsDiffMonth}} />
        </template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6 → Thu, Nov 6",
          "`endAt` should be formatted with weekday, month and date"
        );
    });

    test("formats different years range", async function (assert) {
      await render(
        <template><Dates @event={{events.endsDiffYear}} /></template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6 → Tue, Jan 6, 2026",
          "`endAt` should be formatted with year"
        );
    });
  });

  module("dates and time", function () {
    test("formats yesterday/tomorrow", async function (assert) {
      await render(
        <template>
          <div data-post-id="123">
            <Dates @event={{events.currentYear.yesterdayTomorrow}} />
          </div>
        </template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Yesterday 8:00 AM → Tomorrow 8:00 AM",
          "multi-day events should use relative dates with times"
        );
    });

    test("formats today range", async function (assert) {
      await render(
        <template>
          <div data-post-id="123">
            <Dates @event={{events.currentYear.today}} />
          </div>
        </template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Today 8:00 AM → 9:00 AM (UTC)",
          "same-day events should show times with timezone suffix"
        );
    });

    // this test goest against the current implementation in local-dates
    skip("formats same day range", async function (assert) {
      await render(
        <template><Dates @event={{events.currentYear.endsSameDay}} /></template>
      );

      assert
        .dom(".event-dates")
        .hasText(
          "Mon, Oct 6 12:00 AM → 1:00 AM",
          "`endsAt` should show time only"
        );
    });
  });
});
