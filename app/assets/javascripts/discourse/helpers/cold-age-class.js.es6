export function daysSinceEpoch(dt) {
  // 1000 * 60 * 60 * 24 = days since epoch
  return dt.getTime() / 86400000;
}

/**
  Converts a date to a coldmap class
**/
function coldAgeClass(property, options) {
  var dt = Em.Handlebars.get(this, property, options);
  var className = (options && options.hash && options.hash.class !== undefined) ? options.hash.class : 'age';

  if (!dt) { return className; }

  var startDate = (options && options.hash && options.hash.startDate) || new Date();

  if (typeof startDate === "string") {
    startDate = Em.Handlebars.get(this, startDate, options);
  }

  // Show heat on age
  var nowDays = daysSinceEpoch(startDate),
      epochDays = daysSinceEpoch(new Date(dt));

  if (nowDays - epochDays > Discourse.SiteSettings.cold_age_days_high) return className + ' coldmap-high';
  if (nowDays - epochDays > Discourse.SiteSettings.cold_age_days_medium) return className + ' coldmap-med';
  if (nowDays - epochDays > Discourse.SiteSettings.cold_age_days_low) return className + ' coldmap-low';

  return className;
}

Handlebars.registerHelper('cold-age-class', coldAgeClass);
export default coldAgeClass;
