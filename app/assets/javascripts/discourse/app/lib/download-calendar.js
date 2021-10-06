import User from "discourse/models/user";
import showModal from "discourse/lib/show-modal";
import getURL from "discourse-common/lib/get-url";

export function downloadCalendar(postId, title, dates) {
  const currentUser = User.current();

  const formattedDates = formatDates(dates);

  switch (currentUser.default_calendar) {
    case "none_selected":
      _displayModal(postId, title, formattedDates);
      break;
    case "ics":
      downloadIcs(postId, title, formattedDates);
      break;
    case "google":
      downloadGoogle(title, formattedDates);
      break;
  }
}

export function downloadIcs(postId, title, dates) {
  let datesParam = "";
  dates.forEach((date, index) => {
    datesParam = datesParam.concat(
      `&dates[${index}][starts_at]=${date.startsAt}&dates[${index}][ends_at]=${date.endsAt}`
    );
  });
  const link = getURL(
    `/calendars.ics?post_id=${postId}&title=${title}&${datesParam}`
  );
  window.open(link, "_blank", "noopener", "noreferrer");
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

function _displayModal(postId, title, dates) {
  showModal("download-calendar", { model: { title, postId, dates } });
}

function _formatDateForGoogleApi(date) {
  return moment(date)
    .toISOString()
    .replace(/-|:|\.\d\d\d/g, "");
}
