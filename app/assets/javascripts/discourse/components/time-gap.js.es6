export default Ember.Component.extend({
  classNameBindings: [':time-gap'],

  render(buffer) {
    const gapDays = this.get('gapDays');

    buffer.push("<div class='topic-avatar'><i class='fa fa-clock-o'></i></div>");

    let timeGapWords;
    if (gapDays < 30) {
      timeGapWords = I18n.t('dates.later.x_days', {count: gapDays});
    } else if (gapDays < 365) {
      const gapMonths = Math.floor(gapDays / 30);
      timeGapWords = I18n.t('dates.later.x_months', {count: gapMonths});
    } else {
      const gapYears = Math.floor(gapDays / 365);
      timeGapWords = I18n.t('dates.later.x_years', {count: gapYears});
    }

    buffer.push("<div class='time-gap-words'>" + timeGapWords + "</div>");
  }
});
