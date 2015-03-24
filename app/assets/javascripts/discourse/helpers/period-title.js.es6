import { iconHTML } from 'discourse/helpers/fa-icon';

const TITLE_SUBS = { yearly: 'this_year',
                     monthly: 'this_month',
                     daily: 'today',
                     all: 'all' };

export default Ember.Handlebars.makeBoundHelper(function (period) {
  const title = I18n.t('filters.top.' + (TITLE_SUBS[period] || 'this_week'));
  return new Handlebars.SafeString(iconHTML('calendar-o') + " " + title);
});
