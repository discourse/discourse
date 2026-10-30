import { module, test } from "qunit";
import decorateEventOneboxes from "discourse/plugins/discourse-events/discourse/lib/decorate-event-oneboxes";

const ONEBOX_SRC = "https://other.example.com/t/community-hangout/123";

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

  test("shows the current occurrence from the server", function (assert) {
    const element = buildOnebox({
      startsAt: "2026-10-22T09:00:00.000-04:00",
      endsAt: "2026-10-22T10:00:00.000-04:00",
    });

    decorateEventOneboxes(element, "America/New_York", {
      [ONEBOX_SRC]: {
        starts_at: "2026-11-12T09:00:00.000-05:00",
        ends_at: "2026-11-12T10:00:00.000-05:00",
      },
    });

    assert
      .dom(".discourse-event-onebox__month", element)
      .hasText("Nov", "the month follows the current occurrence");
    assert
      .dom(".discourse-event-onebox__day", element)
      .hasText("12", "the day follows the current occurrence");
    assert
      .dom(".discourse-event-onebox__date", element)
      .hasAttribute(
        "datetime",
        "2026-11-12T09:00:00.000-05:00",
        "the machine-readable date matches the visible one"
      );
    assert
      .dom(".discourse-event-onebox__time-text", element)
      .hasText("9:00 AM → 10:00 AM (EST)", "the time is localized");
  });

  test("keeps the cooked occurrence without server data", function (assert) {
    const element = buildOnebox({
      startsAt: "2026-10-22T09:00:00.000-04:00",
    });

    decorateEventOneboxes(element, "America/New_York");

    assert
      .dom(".discourse-event-onebox__day", element)
      .hasText("22", "the cooked occurrence is shown");
    assert
      .dom(".discourse-event-onebox__date", element)
      .hasAttribute("datetime", "2026-10-22T09:00:00.000-04:00");
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
  startsAt,
  endsAt,
}) {
  const element = document.createElement("div");
  element.innerHTML = `
    <aside class="onebox" data-onebox-src="${ONEBOX_SRC}">
    <div
      class="discourse-event-onebox"
      data-event-all-day="${allDay}"
      data-event-starts-at="${startsAt}"
      data-event-ends-at="${endsAt ?? ""}"
    >
      ${
        dominantColor
          ? `<img class="discourse-event-onebox__image" data-dominant-color="${dominantColor}" width="${imageWidth ?? ""}" height="${imageHeight ?? ""}">`
          : ""
      }
      <time class="discourse-event-onebox__date" datetime="${startsAt}">
        <span class="discourse-event-onebox__month"></span>
        <span class="discourse-event-onebox__day"></span>
      </time>
      <span class="discourse-event-onebox__time-text"></span>
    </div>
    </aside>
  `;
  return element;
}
