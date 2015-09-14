import SmallActionComponent from 'discourse/components/small-action';

export default SmallActionComponent.extend({
  classNames: ['time-gap'],
  classNameBindings: ['hideTimeGap::hidden'],
  hideTimeGap: Em.computed.alias('postStream.hasNoFilters'),
  icon: 'clock-o',

  description: function() {
    const gapDays = this.get('daysAgo');
    if (gapDays < 30) {
      return I18n.t('dates.later.x_days', {count: gapDays});
    } else if (gapDays < 365) {
      const gapMonths = Math.floor(gapDays / 30);
      return I18n.t('dates.later.x_months', {count: gapMonths});
    } else {
      const gapYears = Math.floor(gapDays / 365);
      return I18n.t('dates.later.x_years', {count: gapYears});
    }
  }.property(),
});
