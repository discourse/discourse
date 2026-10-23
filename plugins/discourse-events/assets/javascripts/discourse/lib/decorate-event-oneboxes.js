import moment from "moment";
import { i18n } from "discourse-i18n";

export default function decorateEventOneboxes(element, timezone) {
  element.querySelectorAll(".discourse-event-onebox").forEach((onebox) => {
    const allDay = onebox.dataset.eventAllDay === "true";
    const startsAt = parseDate(onebox.dataset.eventStartsAt, {
      allDay,
      timezone,
    });
    if (!startsAt?.isValid()) {
      return;
    }

    const endsAt = parseDate(onebox.dataset.eventEndsAt, {
      allDay,
      timezone,
    });

    onebox.querySelector(".discourse-event-onebox__month").textContent =
      startsAt.format("MMM");
    onebox.querySelector(".discourse-event-onebox__day").textContent =
      startsAt.format("D");
    onebox.querySelector(".discourse-event-onebox__time-text").textContent =
      allDay
        ? formatAllDay(startsAt, endsAt)
        : formatTimed(startsAt, endsAt, timezone);
  });
}

function formatAllDay(startsAt, endsAt) {
  if (!endsAt?.isValid() || startsAt.isSame(endsAt, "day")) {
    return i18n("discourse_post_event.onebox.all_day");
  }

  return i18n("discourse_post_event.onebox.all_day_range", {
    start: startsAt.format("ll"),
    end: endsAt.format("ll"),
  });
}

function formatTimed(startsAt, endsAt, timezone) {
  let value = startsAt.format("LT");

  if (endsAt?.isValid()) {
    const format = startsAt.isSame(endsAt, "day") ? "LT" : "ll LT";
    value = `${value} → ${endsAt.format(format)}`;
  }

  return `${value} (${timezone})`;
}

function parseDate(value, { allDay, timezone }) {
  if (!value) {
    return null;
  }

  return allDay
    ? moment(value, "YYYY-MM-DD", true)
    : moment.parseZone(value).tz(timezone);
}
