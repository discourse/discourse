import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

const TITLE_SUBS = {
  all: "all_time",
  yearly: "this_year",
  quarterly: "this_quarter",
  monthly: "this_month",
  daily: "today",
};

export default function periodTitle(period, { showDateRange, fullDay } = {}) {
  const title = i18n("filters.top." + (TITLE_SUBS[period] || "this_week"));

  if (!showDateRange) {
    return htmlSafe(title);
  }

  let dateString = "";
  let finish;

  if (fullDay) {
    finish = moment().utc().subtract(1, "days");
  } else {
    finish = moment();
  }

  switch (period) {
    case "yearly":
      dateString =
        finish
          .clone()
          .subtract(1, "year")
          .format(i18n("dates.long_with_year_no_time")) +
        " – " +
        finish.format(i18n("dates.long_with_year_no_time"));
      break;
    case "quarterly":
      dateString =
        finish
          .clone()
          .subtract(3, "month")
          .format(i18n("dates.long_no_year_no_time")) +
        " – " +
        finish.format(i18n("dates.long_no_year_no_time"));
      break;
    case "weekly":
      let start;
      if (fullDay) {
        start = finish.clone().subtract(1, "week");
      } else {
        start = finish.clone().subtract(6, "days");
      }

      dateString =
        start.format(i18n("dates.long_no_year_no_time")) +
        " – " +
        finish.format(i18n("dates.long_no_year_no_time"));
      break;
    case "monthly":
      dateString =
        finish
          .clone()
          .subtract(1, "month")
          .format(i18n("dates.long_no_year_no_time")) +
        " – " +
        finish.format(i18n("dates.long_no_year_no_time"));
      break;
    case "daily":
      dateString = finish.clone().format(i18n("dates.full_no_year_no_time"));
      break;
  }

  return htmlSafe(
    `<span class="date-section">${title}</span><span class='top-date-string'>${dateString}</span>`
  );
}
