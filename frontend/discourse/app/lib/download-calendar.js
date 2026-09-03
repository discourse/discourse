import downloadCalendarModal from "discourse/components/modal/download-calendar";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL from "discourse/lib/get-url";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

export function downloadCalendar(title, dates, options = {}) {
  const currentUser = User.current();

  const formattedDates = formatDates(dates);
  title = (title || i18n("download_calendar.default_title")).trim();

  switch (currentUser?.user_option.default_calendar) {
    case "ics":
      downloadIcs(title, formattedDates, options);
      break;
    case "google":
      downloadGoogle(title, formattedDates, options);
      break;
    case "none_selected":
    default:
      _displayModal(title, formattedDates, options);
  }
}

export function downloadIcs(title, dates, options = {}) {
  const REMOVE_FILE_AFTER = 20_000;
  const file = new File([generateIcsData(title, dates, options)], {
    type: "text/plain",
  });

  const a = document.createElement("a");
  document.body.appendChild(a);
  a.style = "display: none";
  a.href = window.URL.createObjectURL(file);
  a.download = `${title.toLowerCase().replace(/[^\w]/g, "-")}.ics`;
  a.click();
  setTimeout(() => window.URL.revokeObjectURL(file), REMOVE_FILE_AFTER);
}

export function downloadGoogle(title, dates, options = {}) {
  const parsedRrule = _parseRRule(options.rrule);

  dates.forEach((date) => {
    const link = new URL("https://www.google.com/calendar/event");
    link.searchParams.append("action", "TEMPLATE");
    link.searchParams.append("text", title);

    let dateRange;
    if (date.allDay) {
      const { startDate, endDate } = _allDayMoments(date);
      dateRange = `${startDate.format("YYYYMMDD")}/${endDate.format("YYYYMMDD")}`;
    } else {
      dateRange = `${_formatDateForGoogleApi(date.startsAt, date.timezone)}/${_formatDateForGoogleApi(
        date.endsAt,
        date.timezone
      )}`;
    }
    link.searchParams.append("dates", dateRange);

    if (parsedRrule && _hasFreq(parsedRrule)) {
      const rrule = date.allDay ? _dateOnlyUntil(parsedRrule) : parsedRrule;
      link.searchParams.append("recur", `RRULE:${rrule}`);
    }

    if (options.location) {
      link.searchParams.append("location", options.location);
    }

    if (options.details) {
      link.searchParams.append("details", options.details);
    }

    window.open(getURL(link.href).trim(), "_blank", "noopener", "noreferrer");
  });
}

export function formatDates(dates) {
  return dates.map((date) => {
    const formatted = {
      startsAt: date.startsAt,
      endsAt: date.endsAt
        ? date.endsAt
        : date.allDay
          ? null
          : moment.utc(date.startsAt).add(1, "hours").format(),
    };

    // Preserve timezone if present
    if (date.timezone) {
      formatted.timezone = date.timezone;
    }

    if (date.allDay) {
      formatted.allDay = true;
    }

    return formatted;
  });
}

/**
 * Escape special characters in ICS field values per RFC 5545
 * - Backslashes must be escaped as \\
 * - Newlines (CR, LF, CRLF) must be encoded as \n
 * - Semicolons must be escaped as \;
 * - Commas must be escaped as \,
 *
 * @param {string} value - The value to escape
 * @returns {string} - The escaped value
 */
function _escapeIcsValue(value) {
  return value
    .replace(/\\/g, "\\\\")
    .replace(/\r\n|\r|\n/g, "\\n")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,");
}

/**
 * Fold a line to comply with RFC 5545 line length limit (75 octets)
 * Continuation lines start with a space
 *
 * @param {string} line - The line to fold
 * @returns {string} - The folded line
 */
function _foldLine(line) {
  const maxLength = 75;
  if (line.length <= maxLength) {
    return line;
  }

  const result = [];
  let currentLine = line;

  while (currentLine.length > maxLength) {
    result.push(currentLine.substring(0, maxLength));
    currentLine = " " + currentLine.substring(maxLength);
  }
  result.push(currentLine);

  return result.join("\r\n");
}

/**
 * Parse and extract the RRULE line from a string that may contain
 * both DTSTART and RRULE (legacy format)
 *
 * @param {string} rruleString - The RRULE string (may include DTSTART)
 * @returns {string|null} - The extracted RRULE value or null if invalid
 */
function _parseRRule(rruleString) {
  if (!rruleString) {
    return null;
  }

  const lines = rruleString.split(/\r?\n/);

  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith("RRULE:")) {
      return trimmed.substring(6);
    } else if (/^FREQ=/i.test(trimmed)) {
      return trimmed;
    }
  }

  if (/^FREQ=/i.test(rruleString.trim())) {
    return rruleString.trim();
  }

  return null;
}

/**
 * Check if an RRULE string contains the required FREQ parameter
 *
 * @param {string} rrule - The RRULE string to check
 * @returns {boolean} - True if FREQ is present
 */
function _hasFreq(rrule) {
  return /FREQ=/i.test(rrule);
}

function _dateOnlyUntil(rrule) {
  return rrule.replace(/(UNTIL=\d{8})T\d{6}Z?/i, "$1");
}

function _allDayMoments(date) {
  const startDate = moment(date.startsAt, "YYYY-MM-DD");
  const endDate = (
    date.endsAt ? moment(date.endsAt, "YYYY-MM-DD") : startDate.clone()
  ).add(1, "day");
  return { startDate, endDate };
}

const ICAL_WEEKDAYS = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];

function _formatIcsUtcOffset(offsetMinutes) {
  const totalSeconds = Math.round(offsetMinutes * 60);
  const sign = totalSeconds < 0 ? "-" : "+";
  const absoluteSeconds = Math.abs(totalSeconds);
  const hours = Math.floor(absoluteSeconds / 3600);
  const minutes = Math.floor((absoluteSeconds % 3600) / 60);
  const seconds = absoluteSeconds % 60;

  return (
    sign +
    String(hours).padStart(2, "0") +
    String(minutes).padStart(2, "0") +
    (seconds ? String(seconds).padStart(2, "0") : "")
  );
}

const SEASONAL_TRANSITION_WINDOW_MS = 370 * 24 * 60 * 60 * 1000;

function _vTimezoneObservanceType(zone, index) {
  const transitionAt = zone.untils[index];
  const offsetFrom = -zone.offsets[index];
  const offsetTo = -zone.offsets[index + 1];

  const isReverseTransition = (candidateIndex) =>
    -zone.offsets[candidateIndex] === offsetTo &&
    -zone.offsets[candidateIndex + 1] === offsetFrom;

  // Seasonal offset changes reverse within roughly a year. Requiring the
  // reverse transition avoids treating a permanent base-offset change as
  // daylight saving time.
  for (let i = index - 1; i >= 0; i--) {
    if (transitionAt - zone.untils[i] > SEASONAL_TRANSITION_WINDOW_MS) {
      break;
    }

    if (isReverseTransition(i)) {
      return offsetTo > offsetFrom ? "DAYLIGHT" : "STANDARD";
    }
  }

  for (let i = index + 1; i < zone.untils.length - 1; i++) {
    const candidateAt = zone.untils[i];

    if (
      !Number.isFinite(candidateAt) ||
      candidateAt - transitionAt > SEASONAL_TRANSITION_WINDOW_MS
    ) {
      break;
    }

    if (isReverseTransition(i)) {
      return offsetTo > offsetFrom ? "DAYLIGHT" : "STANDARD";
    }
  }

  return "STANDARD";
}

function _vTimezoneTransition(zone, index) {
  const transitionAt = zone.untils[index];
  const offsetFrom = -zone.offsets[index];
  const offsetTo = -zone.offsets[index + 1];
  const localStart = moment.utc(transitionAt).utcOffset(offsetFrom);
  const day = localStart.date();
  const ordinal = day + 7 > localStart.daysInMonth() ? -1 : Math.ceil(day / 7);

  return {
    transitionAt,
    type: _vTimezoneObservanceType(zone, index),
    localStart: localStart.format("YYYYMMDDTHHmmss"),
    year: localStart.year(),
    month: localStart.month() + 1,
    byDay: `${ordinal}${ICAL_WEEKDAYS[localStart.day()]}`,
    time: localStart.format("HHmmss"),
    offsetFrom,
    offsetTo,
    name: zone.abbrs[index + 1],
  };
}

function _vTimezonePatternKey(observance) {
  return JSON.stringify([
    observance.type,
    observance.offsetFrom,
    observance.offsetTo,
    observance.name,
    observance.month,
    observance.byDay,
    observance.time,
  ]);
}

function _vTimezoneBaseKey(observance) {
  return JSON.stringify([
    observance.type,
    observance.offsetFrom,
    observance.offsetTo,
    observance.name,
  ]);
}

function _renderVTimezoneObservance(first, { rrule, rdates = [] } = {}) {
  const lines = [`BEGIN:${first.type}`, `DTSTART:${first.localStart}`];

  if (rrule) {
    lines.push(`RRULE:${rrule}`);
  }

  if (rdates.length) {
    lines.push(`RDATE:${rdates.join(",")}`);
  }

  lines.push(
    `TZOFFSETFROM:${_formatIcsUtcOffset(first.offsetFrom)}`,
    `TZOFFSETTO:${_formatIcsUtcOffset(first.offsetTo)}`
  );

  if (first.name) {
    lines.push(`TZNAME:${first.name}`);
  }

  lines.push(`END:${first.type}`);

  return lines.map(_foldLine).join("\r\n") + "\r\n";
}

function _fixedVTimezone(timezone, referenceMs) {
  const reference = moment.tz(referenceMs, timezone);
  const offset = reference.utcOffset();
  const start = reference
    .clone()
    .subtract(1, "year")
    .startOf("year")
    .format("YYYYMMDDTHHmmss");

  return (
    "BEGIN:VTIMEZONE\r\n" +
    _foldLine(`TZID:${timezone}`) +
    "\r\n" +
    "BEGIN:STANDARD\r\n" +
    `DTSTART:${start}\r\n` +
    `TZOFFSETFROM:${_formatIcsUtcOffset(offset)}\r\n` +
    `TZOFFSETTO:${_formatIcsUtcOffset(offset)}\r\n` +
    _foldLine(`TZNAME:${reference.zoneAbbr()}`) +
    "\r\n" +
    "END:STANDARD\r\n" +
    "END:VTIMEZONE\r\n"
  );
}

function _generateVTimezone(timezone, referenceMs) {
  const zone = moment.tz.zone(timezone);

  if (!zone) {
    return "";
  }

  let startIndex = -1;

  for (let i = 0; i < zone.untils.length - 1; i++) {
    const transitionAt = zone.untils[i];

    if (!Number.isFinite(transitionAt)) {
      break;
    }

    if (transitionAt <= referenceMs) {
      startIndex = i;
    } else {
      break;
    }
  }

  if (startIndex === -1) {
    return _fixedVTimezone(timezone, referenceMs);
  }

  const observances = [];

  for (let i = startIndex; i < zone.untils.length - 1; i++) {
    if (!Number.isFinite(zone.untils[i])) {
      break;
    }

    observances.push(_vTimezoneTransition(zone, i));
  }

  if (!observances.length) {
    return _fixedVTimezone(timezone, referenceMs);
  }

  const maxYear = Math.max(...observances.map((item) => item.year));
  const patternGroups = new Map();

  for (const observance of observances) {
    const key = _vTimezonePatternKey(observance);
    const group = patternGroups.get(key) || [];
    group.push(observance);
    patternGroups.set(key, group);
  }

  const recurringRuns = [];
  const recurringTransitions = new Set();

  for (const group of patternGroups.values()) {
    group.sort((a, b) => a.transitionAt - b.transitionAt);

    let run = [group[0]];

    const finishRun = () => {
      if (run.length >= 2) {
        recurringRuns.push(run);
        for (const observance of run) {
          recurringTransitions.add(observance.transitionAt);
        }
      }
    };

    for (let i = 1; i < group.length; i++) {
      if (group[i].year === group[i - 1].year + 1) {
        run.push(group[i]);
      } else {
        finishRun();
        run = [group[i]];
      }
    }

    finishRun();
  }

  const components = recurringRuns.map((run) => {
    const first = run[0];
    const last = run[run.length - 1];

    let rrule = `FREQ=YEARLY;BYMONTH=${first.month};BYDAY=${first.byDay}`;

    // A long-running pattern which reaches the end of the bundled tzdb data
    // is the zone's stable future rule, so allow it to continue indefinitely.
    if (!(last.year === maxYear && run.length >= 5)) {
      rrule += `;UNTIL=${moment
        .utc(last.transitionAt)
        .format("YYYYMMDDTHHmmss[Z]")}`;
    }

    return {
      first,
      rrule,
      rdates: [],
    };
  });

  const discreteGroups = new Map();

  for (const observance of observances) {
    if (recurringTransitions.has(observance.transitionAt)) {
      continue;
    }

    const key = _vTimezoneBaseKey(observance);
    const group = discreteGroups.get(key) || [];
    group.push(observance);
    discreteGroups.set(key, group);
  }

  for (const group of discreteGroups.values()) {
    group.sort((a, b) => a.transitionAt - b.transitionAt);

    components.push({
      first: group[0],
      rdates: group.slice(1).map((item) => item.localStart),
    });
  }

  components.sort((a, b) => a.first.transitionAt - b.first.transitionAt);

  return (
    "BEGIN:VTIMEZONE\r\n" +
    _foldLine(`TZID:${timezone}`) +
    "\r\n" +
    components
      .map((component) =>
        _renderVTimezoneObservance(component.first, component)
      )
      .join("") +
    "END:VTIMEZONE\r\n"
  );
}

/**
 * Generate ICS calendar data for the given dates
 *
 * @param {string} title - Event title
 * @param {Array} dates - Array of date objects with startsAt, endsAt, optional timezone, and optional allDay (date-only event)
 * @param {Object} options - Optional parameters (rrule, location, details, timezone)
 * @returns {string} - ICS formatted calendar data
 */
export function generateIcsData(title, dates, options = {}) {
  let data = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Discourse//EN\r\n";
  const parsedRrule = _parseRRule(options.rrule);

  const timezoneStarts = new Map();

  for (const date of dates) {
    if (date.allDay) {
      continue;
    }

    const timezone = date.timezone || options.timezone;

    if (!timezone || !moment.tz.zone(timezone)) {
      continue;
    }

    const startsAt = moment.tz(date.startsAt, timezone);

    if (!startsAt.isValid()) {
      continue;
    }

    const existing = timezoneStarts.get(timezone);

    if (existing === undefined || startsAt.valueOf() < existing) {
      timezoneStarts.set(timezone, startsAt.valueOf());
    }
  }

  for (const [timezone, startsAt] of timezoneStarts) {
    data += _generateVTimezone(timezone, startsAt);
  }

  dates.forEach((date) => {
    let rrule = parsedRrule;

    let startDate, endDate, dtStartValue, dtEndValue;

    if (date.allDay) {
      if (rrule) {
        rrule = _dateOnlyUntil(rrule);
      }
      ({ startDate, endDate } = _allDayMoments(date));
      dtStartValue = `DTSTART;VALUE=DATE:${startDate.format("YYYYMMDD")}`;
      dtEndValue = `DTEND;VALUE=DATE:${endDate.format("YYYYMMDD")}`;
    } else {
      const timezone = date.timezone || options.timezone;
      startDate = timezone
        ? moment.tz(date.startsAt, timezone)
        : moment(date.startsAt);
      endDate = timezone
        ? moment.tz(date.endsAt, timezone)
        : moment(date.endsAt);

      dtStartValue = timezone
        ? `DTSTART;TZID=${timezone}:${startDate.format("YYYYMMDDTHHmmss")}`
        : `DTSTART:${startDate.utc().format("YYYYMMDDTHHmmss")}Z`;
      dtEndValue = timezone
        ? `DTEND;TZID=${timezone}:${endDate.format("YYYYMMDDTHHmmss")}`
        : `DTEND:${endDate.utc().format("YYYYMMDDTHHmmss")}Z`;
    }

    data = data.concat(
      "BEGIN:VEVENT\r\n" +
        _foldLine(`UID:${startDate.valueOf()}_${endDate.valueOf()}`) +
        "\r\n" +
        _foldLine(`DTSTAMP:${moment().utc().format("YYYYMMDDTHHmmss")}Z`) +
        "\r\n" +
        _foldLine(dtStartValue) +
        "\r\n" +
        _foldLine(dtEndValue) +
        "\r\n" +
        (rrule && _hasFreq(rrule) ? _foldLine(`RRULE:${rrule}`) + "\r\n" : ``) +
        (options.location
          ? _foldLine(`LOCATION:${_escapeIcsValue(options.location)}`) + "\r\n"
          : ``) +
        (options.details
          ? _foldLine(`DESCRIPTION:${_escapeIcsValue(options.details)}`) +
            "\r\n"
          : ``) +
        _foldLine(`SUMMARY:${_escapeIcsValue(title)}`) +
        "\r\n" +
        "END:VEVENT\r\n"
    );
  });
  data = data.concat("END:VCALENDAR");
  return data;
}

function _displayModal(title, dates, options = {}) {
  const modal = getOwnerWithFallback(this).lookup("service:modal");
  modal.show(downloadCalendarModal, {
    model: {
      calendar: {
        title,
        dates,
        rrule: options.rrule,
        location: options.location,
        details: options.details,
        timezone: options.timezone,
      },
    },
  });
}

function _formatDateForGoogleApi(date, timezone) {
  const momentDate = timezone ? moment.tz(date, timezone) : moment(date);
  return momentDate.utc().format("YYYYMMDD[T]HHmmss[Z]");
}
