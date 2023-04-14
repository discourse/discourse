import I18n from "I18n";
import { htmlHelper } from "discourse-common/lib/helpers";

const TITLE_SUBS = {
  all: "all_time",
  yearly: "this_year",
  quarterly: "this_quarter",
  monthly: "this_month",
  daily: "today",
};

export default htmlHelper((period, options) => {
  const title = I18n.t("filters.top." + (TITLE_SUBS[period] || "this_week"));
  if (options.hash.showDateRange) {
    let dateString = "";
    let finish;

    if (options.hash.fullDay) {
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
            .format(I18n.t("dates.long_with_year_no_time")) +
          " – " +
          finish.format(I18n.t("dates.long_with_year_no_time"));
        break;
      case "quarterly":
        dateString =
          finish
            .clone()
            .subtract(3, "month")
            .format(I18n.t("dates.long_no_year_no_time")) +
          " – " +
          finish.format(I18n.t("dates.long_no_year_no_time"));
        break;
      case "weekly":
        let start;
        if (options.hash.fullDay) {
          start = finish.clone().subtract(1, "week");
        } else {
          start = finish.clone().subtract(6, "days");
        }

        dateString =
          start.format(I18n.t("dates.long_no_year_no_time")) +
          " – " +
          finish.format(I18n.t("dates.long_no_year_no_time"));
        break;
      case "monthly":
        dateString =
          finish
            .clone()
            .subtract(1, "month")
            .format(I18n.t("dates.long_no_year_no_time")) +
          " – " +
          finish.format(I18n.t("dates.long_no_year_no_time"));
        break;
      case "daily":
        dateString = finish
          .clone()
          .format(I18n.t("dates.full_no_year_no_time"));
        break;
    }

    return `<span class="date-section">${title}</span><span class='top-date-string'>${dateString}</span>`;
  } else {
    return title;
  }
});
