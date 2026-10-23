import { module, test } from "qunit";
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
        "11:00 PM → Oct 23, 2026 12:00 AM (Australia/Brisbane)",
        "the time and timezone are localized"
      );
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
});

function buildOnebox({ allDay = false, startsAt, endsAt }) {
  const element = document.createElement("div");
  element.innerHTML = `
    <div
      class="discourse-event-onebox"
      data-event-all-day="${allDay}"
      data-event-starts-at="${startsAt}"
      data-event-ends-at="${endsAt}"
    >
      <span class="discourse-event-onebox__month"></span>
      <span class="discourse-event-onebox__day"></span>
      <span class="discourse-event-onebox__time-text"></span>
    </div>
  `;
  return element;
}
