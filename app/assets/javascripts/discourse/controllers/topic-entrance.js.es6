function entranceDate(dt) {
  var bumpedAt = new Date(dt),
      today = new Date();

  if (bumpedAt.getDate() === today.getDate()) {
    return moment(bumpedAt).format(I18n.t("dates.time"));
  }

  if (bumpedAt.getYear() === today.getYear()) {
    return moment(bumpedAt).format(I18n.t("dates.long_no_year"));
  }

  return moment(bumpedAt).format(I18n.t('dates.long_with_year'));
}

export default Ember.ObjectController.extend({
  position: null,

  topDate: function() {
    return entranceDate(this.get('created_at'));
  }.property('model.created_at'),

  bottomDate: function() {
    return entranceDate(this.get('bumped_at'));
  }.property('model.bumped_at'),

  actions: {
    show: function(data) {
      // Show the chooser but only if the model changes
      if (this.get('model') !== data.topic) {
        this.set('model', data.topic);
        this.set('position', data.position);
      }
    },

    enterTop: function() {
      Discourse.URL.routeTo(this.get('url'));
    },

    enterBottom: function() {
      Discourse.URL.routeTo(this.get('lastPostUrl'));
    }
  }
});
