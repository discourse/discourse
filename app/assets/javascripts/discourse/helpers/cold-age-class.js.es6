export function daysSinceEpoch(dt) {
  // 1000 * 60 * 60 * 24 = days since epoch
  return dt.getTime() / 86400000;
}

/**
  Converts a date to a coldmap class
**/
function coldAgeClass(property, options) {
  var dt = Em.Handlebars.get(this, property, options);

  if (!dt) { return 'age'; }

  // Show heat on age
  var nowDays = daysSinceEpoch(new Date()),
      epochDays = daysSinceEpoch(new Date(dt));
  if (nowDays - epochDays > 60) return 'age coldmap-high';
  if (nowDays - epochDays > 30) return 'age coldmap-med';
  if (nowDays - epochDays > 14) return 'age coldmap-low';

  return 'age';
}

Handlebars.registerHelper('cold-age-class', coldAgeClass);
export default coldAgeClass;
