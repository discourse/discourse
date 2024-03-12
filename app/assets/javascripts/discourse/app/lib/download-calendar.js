import { google, office365 } from "calendar-link";
import downloadCalendarModal from "discourse/components/modal/download-calendar";
import User from "discourse/models/user";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import getURL from "discourse-common/lib/get-url";

export function downloadCalendar(title, dates, recurrenceRule = null) {
  const currentUser = User.current();

  const formattedDates = formatDates(dates);
  title = title.trim();

  switch (currentUser.user_option.default_calendar) {
    case "none_selected":
      _displayModal(title, formattedDates, recurrenceRule);
      break;
    case "ics":
      downloadIcs(title, formattedDates, recurrenceRule);
      break;
    case "google":
      downloadGoogle(title, formattedDates, recurrenceRule);
      break;
    case "office365":
      downloadOffice365(title, formattedDates);
      break;
  }
}

export function downloadIcs(title, dates, recurrenceRule) {
  const REMOVE_FILE_AFTER = 20_000;
  const file = new File([generateIcsData(title, dates, recurrenceRule)], {
    type: "text/plain",
  });

  const a = document.createElement("a");
  document.body.appendChild(a);
  a.style = "display: none";
  a.href = window.URL.createObjectURL(file);
  a.download = `${title.toLowerCase().replace(/[^\w]/g, "-")}.ics`;
  a.click();
  setTimeout(() => window.URL.revokeObjectURL(file), REMOVE_FILE_AFTER); //remove file to avoid memory leaks
}

export function downloadGoogle(title, dates, recurrenceRule) {
  dates.forEach((date) => {
    const event = {
      title,
      start: date.startsAt,
      end: date.endsAt,
      rRule: recurrenceRule,
    };

    window.open(
      getURL(google(event)).trim(),
      "_blank",
      "noopener",
      "noreferrer"
    );
  });
}

export function downloadOffice365(title, dates) {
  dates.forEach((date) => {
    const event = {
      title,
      start: date.startsAt,
      end: date.endsAt,
    };

    window.open(
      getURL(office365(event)).trim(),
      "_blank",
      "noopener",
      "noreferrer"
    );
  });
}

export function formatDates(dates) {
  return dates.map((date) => {
    return {
      startsAt: date.startsAt,
      endsAt: date.endsAt
        ? date.endsAt
        : moment.utc(date.startsAt).add(1, "hours").format(),
    };
  });
}

export function generateIcsData(title, dates, recurrenceRule) {
  let data = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Discourse//EN\n";
  dates.forEach((date) => {
    const startDate = moment(date.startsAt);
    const endDate = moment(date.endsAt);

    data = data.concat(
      "BEGIN:VEVENT\n" +
        `UID:${startDate.utc().format("x")}_${endDate.format("x")}\n` +
        `DTSTAMP:${moment().utc().format("YMMDDTHHmmss")}Z\n` +
        `DTSTART:${startDate.utc().format("YMMDDTHHmmss")}Z\n` +
        `DTEND:${endDate.utc().format("YMMDDTHHmmss")}Z\n` +
        (recurrenceRule ? `RRULE:${recurrenceRule}\n` : ``) +
        `SUMMARY:${title}\n` +
        "END:VEVENT\n"
    );
  });
  data = data.concat("END:VCALENDAR");
  return data;
}

function _displayModal(title, dates, recurrenceRule) {
  const modal = getOwnerWithFallback(this).lookup("service:modal");
  modal.show(downloadCalendarModal, {
    model: { calendar: { title, dates, recurrenceRule } },
  });
}
