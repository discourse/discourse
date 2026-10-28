import { module, test } from "qunit";
import { withFrozenTime } from "discourse/tests/helpers/qunit-helpers";
import decorateEventOneboxes from "discourse/plugins/discourse-events/discourse/lib/decorate-event-oneboxes";

module("Unit | Lib | decorate-event-oneboxes", function () {
  test("localizes timed event oneboxes to the viewer's timezone", function (assert) {
    const element = buildOnebox({
      startsAt: "2026-10-22T13:00:00.000Z",
      endsAt: "2026-10-22T14:00:00.000Z",
    });

    decorateEventOneboxes(element, "Australia/Brisbane");

    assert
      .dom(".discourse-event-onebox__month", element)
      .hasText("Oct", "the month follows the localized date");
    assert
      .dom(".discourse-event-onebox__day", element)
      .hasText("22", "the day follows the localized date");
    assert
      .dom(".discourse-event-onebox__time-text", element)
      .hasText(
        "11:00 PM → Oct 23, 2026 12:00 AM (AEST)",
        "the time and timezone are localized"
      );
  });

  test("labels the timezone with its daylight saving abbreviation", function (assert) {
    const element = buildOnebox({ startsAt: "2026-10-22T13:00:00.000Z" });

    decorateEventOneboxes(element, "America/New_York");

    assert
      .dom(".discourse-event-onebox__time-text", element)
      .hasText("9:00 AM (EDT)", "the abbreviation reflects daylight saving");
  });

  test("labels the timezone with its location when it has no abbreviation", function (assert) {
    const element = buildOnebox({ startsAt: "2026-10-22T13:00:00.000Z" });

    decorateEventOneboxes(element, "America/Sao_Paulo");

    assert
      .dom(".discourse-event-onebox__time-text", element)
      .hasText("10:00 AM (Sao Paulo)", "the location replaces a bare offset");
  });

  test("keeps all-day event dates timezone-independent", function (assert) {
    const element = buildOnebox({
      allDay: true,
      startsAt: "2026-10-22",
      endsAt: "2026-10-22",
    });

    decorateEventOneboxes(element, "Pacific/Honolulu");

    assert
      .dom(".discourse-event-onebox__month", element)
      .hasText("Oct", "the month remains on the authored date");
    assert
      .dom(".discourse-event-onebox__day", element)
      .hasText("22", "the day remains on the authored date");
    assert
      .dom(".discourse-event-onebox__time-text", element)
      .hasText("All day", "the event is identified as all day");
  });

  test("moves a recurring event on to its upcoming occurrence", function (assert) {
    const element = buildOnebox({
      startsAt: "2026-10-22T09:00:00.000-04:00",
      endsAt: "2026-10-22T10:00:00.000-04:00",
      schedule: { frequency: "P1W", byDay: "Thursday" },
    });

    withFrozenTime("2026-11-10T12:00:00Z", "UTC", () =>
      decorateEventOneboxes(element, "America/New_York")
    );

    assert
      .dom(".discourse-event-onebox__month", element)
      .hasText("Nov", "the month follows the upcoming occurrence");
    assert
      .dom(".discourse-event-onebox__day", element)
      .hasText("12", "the day follows the upcoming occurrence");
    assert
      .dom(".discourse-event-onebox__time-text", element)
      .hasText(
        "9:00 AM → 10:00 AM (EST)",
        "the wall-clock time is kept across the DST change"
      );
    assert
      .dom(".discourse-event-onebox__recurrence-text", element)
      .hasText("Every Thursday", "the recurrence is labelled");
  });

  test("keeps an occurrence that is still underway", function (assert) {
    const element = buildOnebox({
      startsAt: "2026-10-22T09:00:00.000-04:00",
      endsAt: "2026-10-22T10:00:00.000-04:00",
      schedule: { frequency: "P1W", byDay: "Thursday" },
    });

    withFrozenTime("2026-10-22T13:30:00Z", "UTC", () =>
      decorateEventOneboxes(element, "America/New_York")
    );

    assert
      .dom(".discourse-event-onebox__day", element)
      .hasText("22", "the current occurrence is shown");
  });

  test("stops at the end of the schedule", function (assert) {
    const element = buildOnebox({
      startsAt: "2026-10-22T09:00:00.000-04:00",
      endsAt: "2026-10-22T10:00:00.000-04:00",
      schedule: { frequency: "P1W", byDay: "Thursday", until: "2026-11-01" },
    });

    withFrozenTime("2026-11-10T12:00:00Z", "UTC", () =>
      decorateEventOneboxes(element, "America/New_York")
    );

    assert
      .dom(".discourse-event-onebox__day", element)
      .hasText("29", "the final occurrence is shown");
    assert
      .dom(".discourse-event-onebox__recurrence-text", element)
      .hasText(
        "Every Thursday until November 1, 2026",
        "the end of the series is included"
      );
  });

  test("moves a monthly event to the same week of the month", function (assert) {
    const element = buildOnebox({
      startsAt: "2026-10-29T09:00:00.000-04:00",
      schedule: { frequency: "P1M", byDay: "Thursday", byMonthWeek: "-1" },
    });

    withFrozenTime("2026-11-10T12:00:00Z", "UTC", () =>
      decorateEventOneboxes(element, "America/New_York")
    );

    assert
      .dom(".discourse-event-onebox__day", element)
      .hasText("26", "the last Thursday of the next month is shown");
    assert
      .dom(".discourse-event-onebox__recurrence-text", element)
      .hasText("The last Thursday of every month");
  });

  test("skips weekends for a weekday event", function (assert) {
    const element = buildOnebox({
      startsAt: "2026-10-23T09:00:00.000-04:00",
      schedule: {
        frequency: "P1D",
        byDay: "Monday,Tuesday,Wednesday,Thursday,Friday",
      },
    });

    withFrozenTime("2026-10-24T12:00:00Z", "UTC", () =>
      decorateEventOneboxes(element, "America/New_York")
    );

    assert
      .dom(".discourse-event-onebox__day", element)
      .hasText("26", "Monday follows Friday");
    assert
      .dom(".discourse-event-onebox__recurrence-text", element)
      .hasText("Every weekday");
  });

  test("moves an all-day event by whole days", function (assert) {
    const element = buildOnebox({
      allDay: true,
      startsAt: "2026-10-22",
      endsAt: "2026-10-22",
      schedule: { frequency: "P1W", byDay: "Thursday" },
    });

    withFrozenTime("2026-10-23T12:00:00Z", "UTC", () =>
      decorateEventOneboxes(element, "UTC")
    );

    assert
      .dom(".discourse-event-onebox__day", element)
      .hasText("29", "the next week's date is shown");
    assert
      .dom(".discourse-event-onebox__time-text", element)
      .hasText("All day");
  });

  test("labels the weekday as the viewer sees it", function (assert) {
    const element = buildOnebox({
      startsAt: "2026-10-22T21:00:00.000-04:00",
      schedule: { frequency: "P1W", byDay: "Thursday" },
    });

    withFrozenTime("2026-10-01T12:00:00Z", "UTC", () =>
      decorateEventOneboxes(element, "Australia/Brisbane")
    );

    assert
      .dom(".discourse-event-onebox__recurrence-text", element)
      .hasText("Every Friday", "Thursday evening in New York is Friday");
  });

  test("catches up on oneboxes fetched years ago", function (assert) {
    const cases = [
      {
        description: "a daily event lands on today",
        startsAt: "2020-01-01T09:00:00.000-05:00",
        schedule: { frequency: "P1D" },
        now: "2026-11-10T12:00:00Z",
        day: "10",
      },
      {
        description: "a weekday event skips the weekend",
        startsAt: "2023-01-02T09:00:00.000-05:00",
        schedule: {
          frequency: "P1D",
          byDay: "Monday,Tuesday,Wednesday,Thursday,Friday",
        },
        now: "2026-10-24T12:00:00Z",
        day: "26",
      },
      {
        description: "a fortnightly event keeps its alternate weeks",
        startsAt: "2026-10-22T09:00:00.000-04:00",
        schedule: { frequency: "P2W", byDay: "Thursday" },
        now: "2027-06-01T12:00:00Z",
        day: "3",
      },
      {
        description: "a monthly event keeps its week of the month",
        startsAt: "2024-01-25T09:00:00.000-05:00",
        schedule: { frequency: "P1M", byDay: "Thursday", byMonthWeek: "-1" },
        now: "2026-11-10T12:00:00Z",
        day: "26",
      },
    ];

    cases.forEach(({ description, startsAt, schedule, now, day }) => {
      const element = buildOnebox({ startsAt, schedule });

      withFrozenTime(now, "UTC", () =>
        decorateEventOneboxes(element, "America/New_York")
      );

      assert
        .dom(".discourse-event-onebox__day", element)
        .hasText(day, description);
      assert
        .dom(".discourse-event-onebox__time-text", element)
        .includesText("9:00 AM", `${description} at the same time`);
    });
  });

  test("leaves an unsupported schedule alone", function (assert) {
    const element = buildOnebox({
      startsAt: "2026-10-22T09:00:00.000-04:00",
      schedule: { frequency: "P3W", byDay: "Thursday" },
    });

    withFrozenTime("2026-11-10T12:00:00Z", "UTC", () =>
      decorateEventOneboxes(element, "America/New_York")
    );

    assert
      .dom(".discourse-event-onebox__day", element)
      .hasText("22", "the fetched occurrence is kept");
  });

  test("exposes the image's dominant color for the letterbox", function (assert) {
    const element = buildOnebox({
      dominantColor: "2A292A",
      startsAt: "2026-10-22T13:00:00.000Z",
    });

    decorateEventOneboxes(element, "UTC");

    assert.strictEqual(
      element
        .querySelector(".discourse-event-onebox")
        .style.getPropertyValue("--event-onebox-image-color"),
      "#2A292A",
      "the color is available to the image styles"
    );
  });

  test("exposes the image's size so the letterbox can fit it", function (assert) {
    const element = buildOnebox({
      dominantColor: "2A292A",
      imageHeight: 300,
      imageWidth: 600,
      startsAt: "2026-10-22T13:00:00.000Z",
    });

    decorateEventOneboxes(element, "UTC");

    const style = element.querySelector(".discourse-event-onebox").style;
    assert.strictEqual(
      style.getPropertyValue("--event-onebox-image-ratio"),
      "0.5",
      "the ratio is available to the image styles"
    );
    assert.strictEqual(
      style.getPropertyValue("--event-onebox-image-height"),
      "300px",
      "the height is available to the image styles"
    );
  });

  test("ignores a malformed dominant color", function (assert) {
    const element = buildOnebox({
      dominantColor: "red; display: none",
      startsAt: "2026-10-22T13:00:00.000Z",
    });

    decorateEventOneboxes(element, "UTC");

    assert.strictEqual(
      element
        .querySelector(".discourse-event-onebox")
        .style.getPropertyValue("--event-onebox-image-color"),
      "",
      "no color is applied"
    );
  });
});

function buildOnebox({
  allDay = false,
  dominantColor,
  imageHeight,
  imageWidth,
  schedule,
  startsAt,
  endsAt,
}) {
  const element = document.createElement("div");
  element.innerHTML = `
    <div
      class="discourse-event-onebox"
      data-event-all-day="${allDay}"
      data-event-starts-at="${startsAt}"
      data-event-ends-at="${endsAt ?? ""}"
      data-event-repeat-frequency="${schedule?.frequency ?? ""}"
      data-event-repeat-by-day="${schedule?.byDay ?? ""}"
      data-event-repeat-by-month-week="${schedule?.byMonthWeek ?? ""}"
      data-event-repeat-until="${schedule?.until ?? ""}"
      data-event-schedule-timezone="${schedule ? "America/New_York" : ""}"
    >
      ${
        dominantColor
          ? `<img class="discourse-event-onebox__image" data-dominant-color="${dominantColor}" width="${imageWidth ?? ""}" height="${imageHeight ?? ""}">`
          : ""
      }
      <span class="discourse-event-onebox__month"></span>
      <span class="discourse-event-onebox__day"></span>
      <span class="discourse-event-onebox__time-text"></span>
      <span class="discourse-event-onebox__recurrence-text"></span>
    </div>
  `;
  return element;
}
