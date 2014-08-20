export default Ember.Object.extend({
  title: null,

  availablePeriods: function() {
    var periods = this.get('periods');
    if (!periods) { return; }

    var self = this;
    return periods.filter(function(p) {
      return p !== self;
    });
  }.property('showMoreUrl'),

  _createTitle: function() {
    var id = this.get('id');
    if (id) {
      var title = "this_week";
      if (id === "yearly") {
        title = "this_year";
      } else if (id === "monthly") {
        title = "this_month";
      } else if (id === "daily") {
        title = "today";
      }

      this.set('title', I18n.t("filters.top." + title));
    }
  }.on('init')

});
