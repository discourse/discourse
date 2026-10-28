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
// After skipping ahead, at most a couple of weeks of weekdays remain to step through
const MAX_STEPS = 20;

export default function decorateEventOneboxes(element, timezone) {
  element.querySelectorAll(".discourse-event-onebox").forEach((onebox) => {
    applyImageStyles(onebox);

    const allDay = onebox.dataset.eventAllDay === "true";
    let startsAt = parseDate(onebox.dataset.eventStartsAt, allDay);
    if (!startsAt?.isValid()) {
      return;
    }

    let endsAt = parseDate(onebox.dataset.eventEndsAt, allDay);
    const schedule = parseSchedule(onebox.dataset);

    // The cooked onebox keeps whichever occurrence was next when it was fetched
    if (schedule) {
      ({ startsAt, endsAt } = upcomingOccurrence(startsAt, endsAt, {
        allDay,
        schedule,
      }));
    }

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
    timezone: moment.tz.zone(dataset.eventScheduleTimezone ?? "")
      ? dataset.eventScheduleTimezone
      : null,
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

function upcomingOccurrence(startsAt, endsAt, { allDay, schedule }) {
  // Stepping in the event's own timezone keeps its wall-clock time across DST changes
  let start =
    !allDay && schedule.timezone
      ? startsAt.clone().tz(schedule.timezone)
      : startsAt.clone();
  const unit = allDay ? "days" : "milliseconds";
  const duration = endsAt?.isValid() ? endsAt.diff(startsAt, unit) : null;
  const until = parseUntil(schedule, allDay);
  const finishesAt = (date) => {
    const end =
      duration === null ? date.clone() : date.clone().add(duration, unit);
    return allDay ? end.endOf("day") : end;
  };

  const now = moment();
  if (finishesAt(start).isBefore(now)) {
    const latestStart = now.clone().subtract(duration ?? 0, unit);
    start = skipAhead(
      start,
      until && until.isBefore(latestStart) ? until : latestStart,
      schedule
    );
  }

  for (let i = 0; i < MAX_STEPS && finishesAt(start).isBefore(now); i++) {
    const next = nextOccurrence(start, schedule);
    if (until && next.isAfter(until)) {
      break;
    }
    start = next;
  }

  return {
    startsAt: start,
    endsAt: duration === null ? endsAt : start.clone().add(duration, unit),
  };
}

// The schedule's end date includes its final day
function parseUntil({ until, timezone }, allDay) {
  if (!until) {
    return null;
  }

  const date =
    allDay || !timezone
      ? moment(until, "YYYY-MM-DD", true)
      : moment.tz(until, "YYYY-MM-DD", true, timezone);
  return date.isValid() ? date.endOf("day") : null;
}

// Jumps whole intervals so the cost doesn't grow with how stale the onebox is. One
// interval is held back because DST can make the diff overshoot; stepping covers the rest.
function skipAhead(start, target, { key, interval, ordinal }) {
  const periods = (unit, size = 1) =>
    Math.max(Math.floor(target.diff(start, unit) / size) - 1, 0);

  switch (key) {
    case "every_day":
      return start.clone().add(periods("days"), "days");
    case "every_month":
      return nthWeekdayOfMonth(
        start.clone().add(periods("months"), "months"),
        start.day(),
        ordinal
      );
    case "every_weekday":
      return start.clone().add(periods("weeks"), "weeks");
    default:
      return start.clone().add(periods("weeks", interval) * interval, "weeks");
  }
}

function nextOccurrence(date, { key, interval, ordinal }) {
  const next = date.clone();

  switch (key) {
    case "every_weekday":
      do {
        next.add(1, "day");
      } while (next.day() === 0 || next.day() === 6);
      return next;
    case "every_month":
      return nthWeekdayOfMonth(next.add(1, "month"), date.day(), ordinal);
    case "every_day":
      return next.add(1, "day");
    default:
      return next.add(interval, "weeks");
  }
}

function nthWeekdayOfMonth(month, weekday, ordinal) {
  if (ordinal === "last") {
    const last = month.clone().date(month.daysInMonth());
    return last.subtract((last.day() - weekday + 7) % 7, "days");
  }

  const nth = Object.values(MONTH_WEEK_ORDINALS).indexOf(ordinal);
  const first = month.clone().date(1);
  return first.add(((weekday - first.day() + 7) % 7) + nth * 7, "days");
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
