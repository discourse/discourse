export default Ember.Component.extend({
  classNames: ["top-title-buttons"],

  periods: function() {
    const period = this.get("period");
    return this.site.get("periods").filter(p => p !== period);
  }.property("period"),

  actions: {
    changePeriod(p) {
      this.sendAction("action", p);
    }
  }
});
