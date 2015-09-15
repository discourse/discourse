import DiscourseURL from 'discourse/lib/url';

function entranceDate(dt, showTime) {
  const today = new Date();

  if (dt.toDateString() === today.toDateString()) {
    return moment(dt).format(I18n.t("dates.time"));
  }

  if (dt.getYear() === today.getYear()) {
    // No year
    return moment(dt).format(
      showTime ? I18n.t("dates.long_date_without_year_with_linebreak") : I18n.t("dates.long_no_year_no_time")
    );
  }

  return moment(dt).format(
    showTime ? I18n.t('dates.long_date_with_year_with_linebreak') : I18n.t('dates.long_date_with_year_without_time')
  );
}

export default Ember.Controller.extend({
  position: null,

  createdDate: function() {
    return new Date(this.get('model.created_at'));
  }.property('model.created_at'),

  bumpedDate: function() {
    return new Date(this.get('model.bumped_at'));
  }.property('model.bumped_at'),

  showTime: function() {
    var diffMs = this.get('bumpedDate').getTime() - this.get('createdDate').getTime();
    return diffMs < (1000 * 60 * 60 * 24 * 2);
  }.property('createdDate', 'bumpedDate'),

  topDate: function() {
    return entranceDate(this.get('createdDate'), this.get('showTime'));
  }.property('createdDate'),

  bottomDate: function() {
    return entranceDate(this.get('bumpedDate'), this.get('showTime'));
  }.property('bumpedDate'),

  actions: {
    show(data) {
      // Show the chooser but only if the model changes
      if (this.get('model') !== data.topic) {
        this.set('model', data.topic);
        this.set('position', data.position);
      }
    },

    enterTop() {
      DiscourseURL.routeTo(this.get('model.url'));
    },

    enterBottom() {
      DiscourseURL.routeTo(this.get('model.lastPostUrl'));
    }
  }
});
