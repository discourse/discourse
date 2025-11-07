import downloadCalendarModal from "discourse/components/modal/download-calendar";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL from "discourse/lib/get-url";
import User from "discourse/models/user";

export function downloadCalendar(title, dates, options = {}) {
  const currentUser = User.current();

  const formattedDates = formatDates(dates);
  title = title.trim();

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
  dates.forEach((date) => {
    const link = new URL("https://www.google.com/calendar/event");
    link.searchParams.append("action", "TEMPLATE");
    link.searchParams.append("text", title);
    link.searchParams.append(
      "dates",
      `${_formatDateForGoogleApi(date.startsAt)}/${_formatDateForGoogleApi(
        date.endsAt
      )}`
    );

    if (options.rrule) {
      link.searchParams.append("recur", `RRULE:${options.rrule}`);
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
        : moment.utc(date.startsAt).add(1, "hours").format(),
    };

    // Preserve timezone if present
    if (date.timezone) {
      formatted.timezone = date.timezone;
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

/**
 * Generate ICS calendar data for the given dates
 *
 * @param {string} title - Event title
 * @param {Array} dates - Array of date objects with startsAt, endsAt, and optional timezone
 * @param {Object} options - Optional parameters (rrule, location, details, timezone)
 * @returns {string} - ICS formatted calendar data
 */
export function generateIcsData(title, dates, options = {}) {
  let data = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Discourse//EN\r\n";
  dates.forEach((date) => {
    const timezone = date.timezone || options.timezone;
    const startDate = timezone
      ? moment.tz(date.startsAt, timezone)
      : moment(date.startsAt);
    const endDate = timezone
      ? moment.tz(date.endsAt, timezone)
      : moment(date.endsAt);
    const rrule = _parseRRule(options.rrule);

    // Format date-time based on whether we have timezone info
    const formatDateTime = (momentObj) => {
      return momentObj.format("YYYYMMDDTHHmmss");
    };

    const dtStartValue = timezone
      ? `DTSTART;TZID=${timezone}:${formatDateTime(startDate)}`
      : `DTSTART:${startDate.utc().format("YYYYMMDDTHHmmss")}Z`;

    const dtEndValue = timezone
      ? `DTEND;TZID=${timezone}:${formatDateTime(endDate)}`
      : `DTEND:${endDate.utc().format("YYYYMMDDTHHmmss")}Z`;

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

function _formatDateForGoogleApi(date) {
  return moment(date)
    .toISOString()
    .replace(/-|:|\.\d\d\d/g, "");
}
