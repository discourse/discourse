import moment from "moment";
import { i18n } from "discourse-i18n";

const HEX_COLOR = /^[0-9a-f]{6}$/i;

export default function decorateEventOneboxes(element, timezone) {
  element.querySelectorAll(".discourse-event-onebox").forEach((onebox) => {
    applyImageStyles(onebox);

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

function applyImageStyles(onebox) {
  const image = onebox.querySelector(".discourse-event-onebox__image");
  if (!image) {
    return;
  }

  const color = image.dataset.dominantColor;
  if (HEX_COLOR.test(color ?? "")) {
    onebox.style.setProperty("--event-onebox-image-color", `#${color}`);
  }

  const width = parseInt(image.getAttribute("width"), 10);
  const height = parseInt(image.getAttribute("height"), 10);
  if (width > 0 && height > 0) {
    onebox.style.setProperty("--event-onebox-image-ratio", height / width);
    onebox.style.setProperty("--event-onebox-image-height", `${height}px`);
  }
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

  return `${value} (${timezoneLabel(startsAt, timezone)})`;
}

// Zones without a common abbreviation format as a bare offset like "-03", so the location reads better
function timezoneLabel(date, timezone) {
  const abbreviation = date.format("z");
  if (!/^[+-]/.test(abbreviation)) {
    return abbreviation;
  }

  return timezone.split("/").pop().replaceAll("_", " ");
}

function parseDate(value, { allDay, timezone }) {
  if (!value) {
    return null;
  }

  return allDay
    ? moment(value, "YYYY-MM-DD", true)
    : moment.parseZone(value).tz(timezone);
}
