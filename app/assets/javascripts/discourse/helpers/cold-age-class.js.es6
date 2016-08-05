import { registerUnbound } from 'discourse/lib/helpers';

function daysSinceEpoch(dt) {
  // 1000 * 60 * 60 * 24 = days since epoch
  return dt.getTime() / 86400000;
}

registerUnbound('cold-age-class', function(dt, params) {
  var className = params['class'] || 'age';

  if (!dt) { return className; }

  var startDate = params.startDate || new Date();

  // Show heat on age
  var nowDays = daysSinceEpoch(startDate),
      epochDays = daysSinceEpoch(new Date(dt));

  if (nowDays - epochDays > Discourse.SiteSettings.cold_age_days_high) return className + ' coldmap-high';
  if (nowDays - epochDays > Discourse.SiteSettings.cold_age_days_medium) return className + ' coldmap-med';
  if (nowDays - epochDays > Discourse.SiteSettings.cold_age_days_low) return className + ' coldmap-low';

  return className;
});

export { daysSinceEpoch };
