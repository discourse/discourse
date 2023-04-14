import { helperContext, registerUnbound } from "discourse-common/lib/helpers";

function daysSinceEpoch(dt) {
  // 1000 * 60 * 60 * 24 = days since epoch
  return dt.getTime() / 86400000;
}

registerUnbound("cold-age-class", function (dt, params) {
  let className = params["class"] || "age";

  if (!dt) {
    return className;
  }

  let startDate = params.startDate || new Date();

  // Show heat on age
  let nowDays = daysSinceEpoch(startDate),
    epochDays = daysSinceEpoch(new Date(dt));

  let siteSettings = helperContext().siteSettings;
  if (nowDays - epochDays > siteSettings.cold_age_days_high) {
    return className + " coldmap-high";
  }
  if (nowDays - epochDays > siteSettings.cold_age_days_medium) {
    return className + " coldmap-med";
  }
  if (nowDays - epochDays > siteSettings.cold_age_days_low) {
    return className + " coldmap-low";
  }

  return className;
});

export { daysSinceEpoch };
