import User from "discourse/models/user";
import showModal from "discourse/lib/show-modal";
import getURL from "discourse-common/lib/get-url";

export function downloadCalendar(title, dates) {
  const currentUser = User.current();

  const formattedDates = formatDates(dates);
  title = title.trim();

  switch (currentUser.user_option.default_calendar) {
    case "none_selected":
      _displayModal(title, formattedDates);
      break;
    case "ics":
      downloadIcs(title, formattedDates);
      break;
    case "google":
      downloadGoogle(title, formattedDates);
      break;
  }
}

export function downloadIcs(title, dates) {
  const REMOVE_FILE_AFTER = 20_000;
  const file = new File([generateIcsData(title, dates)], {
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

export function downloadGoogle(title, dates) {
  dates.forEach((date) => {
    const encodedTitle = encodeURIComponent(title);
    const link = getURL(`
      https://www.google.com/calendar/event?action=TEMPLATE&text=${encodedTitle}&dates=${_formatDateForGoogleApi(
      date.startsAt
    )}/${_formatDateForGoogleApi(date.endsAt)}
    `).trim();
    window.open(link, "_blank", "noopener", "noreferrer");
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

export function generateIcsData(title, dates) {
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
        `SUMMARY:${title}\n` +
        "END:VEVENT\n"
    );
  });
  data = data.concat("END:VCALENDAR");
  return data;
}

function _displayModal(title, dates) {
  showModal("download-calendar", { model: { title, dates } });
}

function _formatDateForGoogleApi(date) {
  return moment(date)
    .toISOString()
    .replace(/-|:|\.\d\d\d/g, "");
}
