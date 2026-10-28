import moment from "moment";
import { i18n } from "discourse-i18n";

const HEX_COLOR = /^[0-9a-f]{6}$/i;
const REPEAT_FREQUENCY = /^P(\d+)([DWM])$/;
const WORKWEEK = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
const MONTH_WEEK_ORDINALS = {
  1: "first",
  2: "second",
  3: "third",
  4: "fourth",
  "-1": "last",
};

/**
 * @param {Element} element
 * @param {string} timezone - the viewer's timezone
 * @param {Object} [occurrences] - current occurrences of recurring events, keyed by
 *   onebox source URL, for oneboxes whose cooked occurrence has passed
 */
export default function decorateEventOneboxes(
  element,
  timezone,
  occurrences = {}
) {
  element.querySelectorAll(".discourse-event-onebox").forEach((onebox) => {
    applyImageStyles(onebox);

    const src = onebox.closest("aside.onebox")?.dataset.oneboxSrc;
    const occurrence = (src && occurrences?.[src]) || {
      starts_at: onebox.dataset.eventStartsAt,
      ends_at: onebox.dataset.eventEndsAt,
    };

    const allDay = onebox.dataset.eventAllDay === "true";
    let startsAt = parseDate(occurrence.starts_at, allDay);
    if (!startsAt?.isValid()) {
      return;
    }

    let endsAt = parseDate(occurrence.ends_at, allDay);
    const schedule = parseSchedule(onebox.dataset);

    onebox
      .querySelector(".discourse-event-onebox__date")
      ?.setAttribute("datetime", occurrence.starts_at);

    if (!allDay) {
      startsAt = startsAt.tz(timezone);
      endsAt = endsAt?.tz(timezone);
    }

    onebox.querySelector(".discourse-event-onebox__month").textContent =
      startsAt.format("MMM");
    onebox.querySelector(".discourse-event-onebox__day").textContent =
      startsAt.format("D");
    onebox.querySelector(".discourse-event-onebox__time-text").textContent =
      allDay
        ? formatAllDay(startsAt, endsAt)
        : formatTimed(startsAt, endsAt, timezone);

    const recurrence = onebox.querySelector(
      ".discourse-event-onebox__recurrence-text"
    );
    if (recurrence && schedule) {
      recurrence.textContent = recurrenceLabel(schedule, startsAt);
    }
  });
}

function parseSchedule(dataset) {
  const match = REPEAT_FREQUENCY.exec(dataset.eventRepeatFrequency ?? "");
  if (!match) {
    return null;
  }

  const byDay = dataset.eventRepeatByDay?.split(",").filter(Boolean) ?? [];
  const schedule = {
    interval: parseInt(match[1], 10),
    unit: { D: "days", W: "weeks", M: "months" }[match[2]],
    byDay,
    ordinal: MONTH_WEEK_ORDINALS[dataset.eventRepeatByMonthWeek],
    until: dataset.eventRepeatUntil || null,
  };
  schedule.key = recurrenceKey(schedule);

  return schedule.key ? schedule : null;
}

// Mirrors the patterns the event builder can create, so the builder's labels apply
function recurrenceKey({ interval, unit, byDay, ordinal }) {
  if (unit === "days" && interval === 1) {
    if (byDay.length === 0) {
      return "every_day";
    }

    const isWorkweek =
      byDay.length === WORKWEEK.length &&
      WORKWEEK.every((day) => byDay.includes(day));
    return isWorkweek ? "every_weekday" : null;
  }

  if (unit === "weeks") {
    return (
      { 1: "every_week", 2: "every_two_weeks", 4: "every_four_weeks" }[
        interval
      ] ?? null
    );
  }

  if (unit === "months" && interval === 1 && ordinal) {
    return "every_month";
  }

  return null;
}

function recurrenceLabel(schedule, startsAt) {
  const recurrence = i18n(
    `discourse_post_event.builder_modal.recurrence.${schedule.key}`,
    {
      weekday: startsAt.format("dddd"),
      ordinal: schedule.ordinal
        ? i18n(
            `discourse_post_event.builder_modal.recurrence.ordinals.${schedule.ordinal}`
          )
        : undefined,
    }
  );

  const until = schedule.until && moment(schedule.until, "YYYY-MM-DD", true);
  if (!until?.isValid()) {
    return recurrence;
  }

  return i18n("discourse_post_event.onebox.recurrence_until", {
    recurrence,
    date: until.format("LL"),
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

function parseDate(value, allDay) {
  if (!value) {
    return null;
  }

  return allDay ? moment(value, "YYYY-MM-DD", true) : moment.parseZone(value);
}
